from flask import json, jsonify, request
from flask_jwt_extended import create_access_token, jwt_required, get_jwt_identity
from flask_jwt_extended import jwt_required, get_jwt_identity, create_access_token
import bcrypt
from app import mysql
import datetime

# Please install OpenAI SDK first: `pip3 install openai`
from openai import OpenAI
from dotenv import load_dotenv
from config import Config


class ApiDeepSeekModel:
    @staticmethod
    def test_api(system_prompt, user_prompt):
        client = OpenAI(
            api_key=Config.DEEPSEEK_APIKEY, base_url="https://api.deepseek.com"
        )

        # Extraer correctamente el contenido del system prompt
        system_content = (
            system_prompt[0]["prompt_value"]
            if isinstance(system_prompt[0], dict)
            else system_prompt[0]
        )

        PromptRules = """
            FORMATO DE ENTRADA: El input SIEMPRE será un JSON con la clave 'exam_data', que contiene una lista de bloques. Cada bloque representa un texto o audio con un conjunto de preguntas. Cada pregunta contiene:-question_text: el texto de la pregunta.-section: READING o LISTENING comprehension.-student_answer: la respuesta proporcionada por el estudiante.-is_correct: indica si fue respondida correctamente.-title: el texto o contexto que se usó para las preguntas.-title_type: puede ser 'READING' o 'LISTENING'. Este es el formato fijo y no modificable del input:{'exam_data':[{'questions':[{'is_correct':false,'question_text':'When is the application deadline?','section':'Reading comprehension','student_answer':'June 15th'},{'is_correct':true,'question_text':'What type of internships are being offered?','section':'Reading comprehension','student_answer':'Summer internships'}],'title':'We are offering summer internships for undergraduate students in the Marketing and IT departments. Apply before May 30th.','title_type':'READING'}]} Este es el formato fijo y no modificable del OUTPUT, en el caso de strengths, weaknesses y recommendations necesito que seas detallado enfocandote en casos específicos de las respuestas del estudiante, si encontrases mas de una strengths, weaknesses o recommendations puedes agregarlas, el obejtivo es que el estudiante vea todas esos detalles y le sean de utilidad para su estudio:{'mcer_level':'B1','toeic_score':720,'passed':true,'strengths':['aquí irán x cantidad de fortalezas del estudiante'],'weaknesses':['aquí irán lx cantidad de debilidades del estudiante'],'recommendations':['aquí irán x cantidad de recomendaciones para el estudiante']}
            """

        system_content += PromptRules

        messages = [
            {"role": "system", "content": system_content},
            {
                "role": "user",
                "content": json.dumps(user_prompt),
            },  # Convertir a JSON string
        ]

        try:
            response = client.chat.completions.create(
                model="deepseek-chat",
                messages=messages,
                response_format={"type": "json_object"},
            )
            response_data = json.loads(response.choices[0].message.content)
            return response_data
        except Exception as e:
            print(f"Error calling DeepSeek API: {str(e)}")
            return None

    @staticmethod
    def query_deepseek_api(question_text, student_answer, correct_answer, title_test):
        try:
            if not Config.DEEPSEEK_APIKEY:
                raise ValueError("API key required")

            client = OpenAI(api_key=Config.DEEPSEEK_APIKEY, base_url="https://api.deepseek.com")

            system_content = (
                    "Eres especialista en TOEIC:Si student_answer != correct_answer → 'incorrecta'.\n"
                    "{"
                    '   "evaluacion": "correcta/incorrecta",'
                    '   "explicacion": ["texto"],'
                    '   "sugerencias": ["texto"]'
                    "}"
                    "Contexto:" + title_test
                )

            # Prompt user minimalista 
            user_prompt = (
                "question:" + question_text[:150] + "|"
                "student_answer:" + student_answer[:100] + "|"
                "correct_answer:" + correct_answer[:100]
            )

            response = client.chat.completions.create(
                model="deepseek-chat",
                messages=[
                    {"role": "system", "content": system_content},
                    {"role": "user", "content": user_prompt}
                ],
                response_format={"type": "json_object"},
                temperature=0.4,  # Más determinista
                max_tokens=500,   # Suficiente para respuesta estructurada
                top_p=0.9
            )

            # Parseo directo manteniendo estructura
            return json.loads(response.choices[0].message.content)

        except Exception as e:
            print(f"API error:{str(e)}")
            return None
        
        
    @staticmethod
    def check_usage_limit(user_id, endpoint='ai_comment', max_requests=5):
        """
        Verifica si el usuario ha excedido el límite de peticiones
        
        Args:
            user_id (int): ID del usuario
            endpoint (str): Nombre del endpoint (default 'ai_comment')
            max_requests (int): Límite máximo de peticiones (default 5)
            
        Returns:
            tuple: (bool, int) - (True si puede continuar, requests_remaining)
        """
        cur = mysql.connection.cursor()
        query = """
            SELECT count, pk_log 
            FROM api_usage_log 
            WHERE fk_user = %s 
            AND endpoint = %s 
            AND request_date = CURRENT_DATE
        """
        values = (user_id, endpoint)

        try:
            cur.execute(query, values)
            result = cur.fetchone()
            
            if result and result['count'] >= max_requests:
                return False, 0
            return True, max_requests - (result['count'] if result else 0)
        except Exception as e:
            print("Error al verificar límite de uso:", e)
            return True, max_requests  # Fallback para no bloquear en caso de error
        finally:
            cur.close()

    @staticmethod
    def log_request(user_id, endpoint='ai_comment'):
        """
        Registra una nueva petición en el log de uso
        
        Args:
            user_id (int): ID del usuario
            endpoint (str): Nombre del endpoint (default 'ai_comment')
            
        Returns:
            int: Número de peticiones realizadas hoy
        """
        cur = mysql.connection.cursor()
        
        # Primero intentamos actualizar un registro existente
        update_query = """
            UPDATE api_usage_log 
            SET count = count + 1, 
                last_request_at = NOW() 
            WHERE fk_user = %s 
            AND endpoint = %s 
            AND request_date = CURRENT_DATE
        """
        update_values = (user_id, endpoint)

        try:
            cur.execute(update_query, update_values)
            if cur.rowcount > 0:
                mysql.connection.commit()
                
                # Obtenemos el nuevo conteo
                count_query = """
                    SELECT count FROM api_usage_log 
                    WHERE fk_user = %s 
                    AND endpoint = %s 
                    AND request_date = CURRENT_DATE
                """
                cur.execute(count_query, (user_id, endpoint))
                result = cur.fetchone()
                return result['count'] if result else 1
            else:
                # Si no hay registros para actualizar, insertamos uno nuevo
                insert_query = """
                    INSERT INTO api_usage_log 
                    (fk_user, endpoint, request_date) 
                    VALUES (%s, %s, CURRENT_DATE)
                """
                cur.execute(insert_query, (user_id, endpoint))
                mysql.connection.commit()
                return 1
        except Exception as e:
            print("Error al registrar petición:", e)
            mysql.connection.rollback()
            return 0
        finally:
            cur.close()

    @staticmethod
    def get_usage_history(user_id, days=30):
        """
        Obtiene el historial de uso de un usuario
        
        Args:
            user_id (int): ID del usuario
            days (int): Número de días de historial a recuperar
            
        Returns:
            list: Lista de registros de uso o None en caso de error
        """
        cur = mysql.connection.cursor()
        query = """
            SELECT request_date, endpoint, count 
            FROM api_usage_log 
            WHERE fk_user = %s 
            AND request_date >= CURRENT_DATE - INTERVAL %s DAY
            ORDER BY request_date DESC
        """
        values = (user_id, days)

        try:
            cur.execute(query, values)
            return cur.fetchall()
        except Exception as e:
            print("Error al obtener historial de uso:", e)
            return None
        finally:
            cur.close()
