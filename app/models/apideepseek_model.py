from flask import json, jsonify, request
from flask_jwt_extended import create_access_token, jwt_required, get_jwt_identity
from flask_jwt_extended import jwt_required, get_jwt_identity, create_access_token
import bcrypt
from app import mysql
import datetime
import json
import uuid
from datetime import datetime
from flask import current_app
from google.cloud import texttospeech, storage

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
            FORMATO DE ENTRADA: El input SIEMPRE será un JSON. Explicacion de los campos del json de entrada(tomar en cuenta para los calculos del puntaje, y nivel MCER):
            title: se entiende que es el escenario ficticio o el texto desde el cual las preguntas suelen hacerse
            title_type: es el tipo de categoria de preguntas TOEIC, este campo puede tener el valor LISTENING o READING y es una propiedad del "title" por lo que el "title" define el tipo de categoria de sus preguntas.
            is_correct: si es true es correcta y si es false es incorrecta
            question_text: es el texto de la pregunta que se hace a partir del texto que se encuentra en "title"
            section: es la seccion de las preguntas que se hacen por ejemplo, Incomplete sentences, Error recognition, Reading comprehension, Double passages, Question - Response, Short conversation, Short talks
            student_answer: es la respuesta que el estudiante selecciono
            Este es el formato fijo y no modificable del input:
            EJEMPLO INPUT:
            [{"questions":[{"is_correct":false,"question_text":"When is the application deadline?","section":"Reading comprehension","student_answer":"June 15th"},{"is_correct":true,"question_text":"What type of internships are being offered?","section":"Reading comprehension","student_answer":"Summer internships"}],"title":"We are offering summer internships for undergraduate students in the Marketing and IT departments. Apply before May 30th.","title_type":"READING"}]
            Este es el formato fijo y no modificable del OUTPUT, en el caso de strengths, weaknesses y recommendations necesito que seas detallado enfocandote en casos específicos de las respuestas del estudiante y el como el estudiante puede mejorar en los temas relacionados en ellos, si encontrases mas de una strengths, weaknesses o recommendations puedes agregarlas, el objetivo es que el estudiante vea todas esos detalles y le sean de utilidad para su estudio:
            En caso de no encontrar un strengths, weaknesses o recommendations, sin comentarios a destacar. Estos textos deben de ser en español. 
            EJEMPLO OUTPUT:
            {"mcer_level":"B1","toeic_score":720,"passed":true,"strengths":["aquí irán x cantidad de fortalezas del estudiante"],"weaknesses":["aquí irán lx cantidad de debilidades del estudiante"],"recommendations":["aquí irán x cantidad de recomendaciones para el estudiante"]}
            """

        print(json.dumps(user_prompt))
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
                    "Eres especialista en TOEIC:Si student_answer != correct_answer → 'incorrecta. OUTPUT JSON'.\n"
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
            
            
            
    @staticmethod
    def get_context_from_db(level_fk, toeic_section_fk):
        """Obtiene los nombres del nivel y la sección para el prompt."""
        try:
            cur = mysql.connection.cursor()
            query = """
                SELECT 
                    (SELECT level_name FROM mcer_level WHERE pk_level = %s) as level,
                    (SELECT section_desc FROM toeic_sections WHERE section_pk = %s) as section;
            """
            cur.execute(query, (level_fk, toeic_section_fk))
            result = cur.fetchone()
            cur.close()
            return result if result else None
        except Exception as e:
            print(f"Error getting context from DB: {e}")
            return None

    @staticmethod
    def generate_quiz_content(level_fk, toeic_section_fk, title_type, topic):
        #Llama a la API de DeepSeek para generar un título con 4 preguntas y 4 respuestas cada una
        try:
            if not Config.DEEPSEEK_APIKEY:
                raise ValueError("API key para DeepSeek no configurada")

            context = ApiDeepSeekModel.get_context_from_db(level_fk, toeic_section_fk)
            if not context:
                raise ValueError("No se pudo obtener el contexto desde la base de datos.")

            # --- Instrucciones específicas para el formato de Listening ---
            listening_format_instructions = ""
            if title_type.upper() == 'LISTENING':
                listening_format_instructions = (
                    "Para el campo 'title_test', genera un script de conversación. "
                    "DEBE seguir estrictamente el formato: 'person 1: texto', 'person 2: texto', etc. "
                    "Los actores pueden ser 'default', 'person 1', 'person 2', 'person 3', 'person 4' y cada linea del script debe finalizar en un salto de linea y sin punto",
                    "El actor 'default' siempre debe de iniciar con una breve introduccion de nomas de 6 palabras, y omite el uso de 'person 1', 'person 2'... como parte de las preguntas."
                )

            # --- Construcción del Prompt del Sistema ---
            system_prompt = f"""
                Eres un experto creando contenido para el examen TOEIC.
                Tu tarea es generar un JSON que contenga un título ({title_type}), 4 preguntas relacionadas y 4 respuestas para cada pregunta.
                El nivel de dificultad debe ser {context['level']}.
                La sección de TOEIC es: {context['section']}.
                El tema de conversacion es: {topic}.
                {listening_format_instructions}

                La estructura del JSON de salida DEBE ser la siguiente y no incluyas nada más fuera del JSON:
                {{
                  "title_name": "Un nombre creativo para el título",
                  "title_test": "El texto completo si es Reading, o el script de la conversación si es Listening",
                  "title_type": "{title_type.upper()}",
                  "questions": [
                    {{
                      "question_text": "Texto de la pregunta 1...",
                      "answers": [
                        {{"answer_text": "Respuesta A.", "is_correct": false}},
                        {{"answer_text": "Respuesta B.", "is_correct": true}},
                        {{"answer_text": "Respuesta C.", "is_correct": false}},
                        {{"answer_text": "Respuesta D.", "is_correct": false}}
                      ]
                    }}
                  ]
                }}

                Asegúrate de que:
                1. Haya exactamente 4 objetos en la lista "questions".
                2. Cada objeto de pregunta tenga exactamente 4 objetos de respuesta en su lista "answers".
                3. En cada lista de respuestas, exactamente UNO de los objetos tenga "is_correct": true.
            """

            client = OpenAI(api_key=Config.DEEPSEEK_APIKEY, base_url="https://api.deepseek.com")
            
            response = client.chat.completions.create(
                model="deepseek-chat",
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": f"Genera el contenido para un examen nivel {context['level']} de tipo {title_type} sobre {context['section']} con contenido de {topic}."}
                ],
                response_format={"type": "json_object"},
                temperature=0.7,
                max_tokens=2048
            )
            
            return json.loads(response.choices[0].message.content)

        except Exception as e:
            print(f"Error en la API de IA: {str(e)}")
            return None
        
        
    # --- MÉTODO DE GUARDADO ---
    @staticmethod
    def save_quiz_to_db(quiz_data, level_fk, toeic_section_fk):
        #Guarda el título, preguntas y respuestas en la BD usando una transacción.
        conn = mysql.connection
        cur = conn.cursor()
        audio_url = None
        blob = None # Referencia al archivo en GCS para posible eliminación

        try:
            # --- 1. Generar audio si el tipo es LISTENING (ANTES de tocar la BD) ---
            if quiz_data.get('title_type') == 'LISTENING':
                #print("Tipo LISTENING detectado. Iniciando generación de audio...")
                audio_url, blob = ApiDeepSeekModel._generate_and_upload_audio(quiz_data['title_test'])
                #print(f"Audio generado y subido a: {audio_url}")

            # --- 2. Insertar el título en la BD ---
            # Ahora usamos la variable 'audio_url' que contiene la URL de GCS o es None
            title_query = """
                INSERT INTO questions_titles (title_name, title_test, title_type, title_url, status)
                VALUES (%s, %s, %s, %s, 'ACTIVE')
            """
            cur.execute(title_query, (
                quiz_data['title_name'],
                quiz_data['title_test'],
                quiz_data['title_type'],
                audio_url # Aquí se guarda la URL del audio o NULL
            ))
            new_title_id = cur.lastrowid

            # --- 3. Iterar e insertar cada pregunta y respuesta (sin cambios) ---
            for q in quiz_data['questions']:
                question_query = """
                    INSERT INTO questions (toeic_section_fk, question_text, title_fk, level_fk, status)
                    VALUES (%s, %s, %s, %s, 'ACTIVE')
                """
                cur.execute(question_query, (toeic_section_fk, q['question_text'], new_title_id, level_fk))
                new_question_id = cur.lastrowid

                for ans in q['answers']:
                    answer_query = """
                        INSERT INTO answers (question_fk, answer_text, is_correct, status)
                        VALUES (%s, %s, %s, 'ACTIVE')
                    """
                    cur.execute(answer_query, (new_question_id, ans['answer_text'], ans['is_correct']))
            
            # Si todo fue exitoso, confirmar la transacción
            conn.commit()
            return new_title_id

        except Exception as e:
            # Si algo falla, revertir todos los cambios de la BD
            conn.rollback()
            #print(f"Error en save_quiz_to_db, transacción revertida: {str(e)}")

            # --- 4. Lógica de limpieza para GCS ---
            # Si se creó un archivo en GCS pero la transacción falló, elimínalo.
            if blob:
                try:
                    #print(f"La transacción de BD falló. Eliminando archivo huérfano de GCS: {blob.name}")
                    blob.delete()
                    #print("Archivo huérfano eliminado exitosamente.")
                except Exception as gcs_error:
                    print(f"¡CRÍTICO! No se pudo eliminar el archivo huérfano de GCS: {blob.name}. Error: {gcs_error}")
            
            return None
        finally:
            cur.close()
            
    # --- ✨ MÉTODO AUXILIAR PRIVADO PARA GENERAR AUDIO ---
    @staticmethod
    def _generate_and_upload_audio(script_content):
        
        #Genera SSML, crea el audio con Google TTS y lo sube a GCS.
        #Devuelve la URL pública del audio y el objeto blob para posible eliminación.
        
        try:
            # 1. Generar SSML a partir del script
            VOICE_MAPPING = {
                'person 1': 'en-US-Standard-I', 'person 2': 'en-US-Standard-H',
                'person 3': 'en-US-Standard-C', 'person 4': 'en-US-Standard-D',
                'default': 'en-US-Standard-B'
            }
            ssml_parts = ['<speak>']
            previous_speaker = None
            for line in script_content.split('\n'):
                line = line.strip()
                if not line: continue
                
                speaker_key = 'default'
                text_to_speak = line
                if ': ' in line:
                    speaker, text = line.split(': ', 1)
                    speaker_key = speaker.strip().lower()
                    text_to_speak = text.strip()
                
                voice_name = VOICE_MAPPING.get(speaker_key, VOICE_MAPPING['default'])
                ssml_parts.append(f'<voice name="{voice_name}">{text_to_speak}<break time="350ms"/></voice>')
                
                if previous_speaker and previous_speaker != speaker_key:
                    ssml_parts.append('<break time="600ms"/>')
                previous_speaker = speaker_key
            
            ssml_parts.append('</speak>')
            ssml = ''.join(ssml_parts)

            # 2. Generar audio con Google TTS
            tts_client = texttospeech.TextToSpeechClient()
            synthesis_input = texttospeech.SynthesisInput(ssml=ssml)
            voice_params = texttospeech.VoiceSelectionParams(language_code="en-US")
            audio_config = texttospeech.AudioConfig(audio_encoding=texttospeech.AudioEncoding.MP3)
            response = tts_client.synthesize_speech(input=synthesis_input, voice=voice_params, audio_config=audio_config)

            # 3. Subir a Google Cloud Storage
            storage_client = storage.Client()
            bucket = storage_client.bucket(current_app.config['GCS_BUCKET_NAME'])
            filename = f"audios/{datetime.now().strftime('%Y%m%d')}-{uuid.uuid4().hex}.mp3"
            blob = bucket.blob(filename)
            blob.upload_from_string(response.audio_content, content_type='audio/mpeg')
            
            audio_url = f"https://storage.googleapis.com/{current_app.config['GCS_BUCKET_NAME']}/{blob.name}"
            
            # Devuelve la URL y el blob para el manejo de la transacción
            return audio_url, blob

        except Exception as e:
            print(f"Error durante la generación o subida del audio: {e}")
            raise e # Lanza la excepción para que la transacción principal la capture y haga rollback

