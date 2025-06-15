from flask import json, jsonify, request
from flask_jwt_extended import create_access_token, jwt_required, get_jwt_identity
from flask_jwt_extended import jwt_required, get_jwt_identity, create_access_token
import bcrypt
from app import mysql
# Please install OpenAI SDK first: `pip3 install openai`
from openai import OpenAI
from dotenv import load_dotenv 
from config import Config

class ApiDeepSeekModel:
    @staticmethod
    def test_api(system_prompt, user_prompt):
        client = OpenAI(api_key=Config.DEEPSEEK_APIKEY, base_url="https://api.deepseek.com")
     
        # Extraer correctamente el contenido del system prompt
        system_content = system_prompt[0]['prompt_value'] if isinstance(system_prompt[0], dict) else system_prompt[0]
        
        PromptRules= """
            FORMATO DE ENTRADA: El input SIEMPRE será un JSON con la clave 'exam_data', que contiene una lista de bloques. Cada bloque representa un texto o audio con un conjunto de preguntas. Cada pregunta contiene:-question_text: el texto de la pregunta.-section: READING o LISTENING comprehension.-student_answer: la respuesta proporcionada por el estudiante.-is_correct: indica si fue respondida correctamente.-title: el texto o contexto que se usó para las preguntas.-title_type: puede ser 'READING' o 'LISTENING'. Este es el formato fijo y no modificable del input:{'exam_data':[{'questions':[{'is_correct':false,'question_text':'When is the application deadline?','section':'Reading comprehension','student_answer':'June 15th'},{'is_correct':true,'question_text':'What type of internships are being offered?','section':'Reading comprehension','student_answer':'Summer internships'}],'title':'We are offering summer internships for undergraduate students in the Marketing and IT departments. Apply before May 30th.','title_type':'READING'}]} Este es el formato fijo y no modificable del OUTPUT, en el caso de strengths, weaknesses y recommendations necesito que seas detallado enfocandote en casos específicos de las respuestas del estudiante, si encontrases mas de una strengths, weaknesses o recommendations puedes agregarlas, el obejtivo es que el estudiante vea todas esos detalles y le sean de utilidad para su estudio:{'mcer_level':'B1','toeic_score':720,'passed':true,'strengths':['aquí irán x cantidad de fortalezas del estudiante'],'weaknesses':['aquí irán lx cantidad de debilidades del estudiante'],'recommendations':['aquí irán x cantidad de recomendaciones para el estudiante']}
            """
          
        system_content += PromptRules  
        
        messages = [
            {"role": "system", "content": system_content},
            {"role": "user", "content": json.dumps(user_prompt)}  # Convertir a JSON string
        ]
        
        try:
            response = client.chat.completions.create(
                model="deepseek-chat",
                messages=messages,
                response_format={'type': 'json_object'}
            )
            response_data = json.loads(response.choices[0].message.content)
            return response_data
        except Exception as e:
            print(f"Error calling DeepSeek API: {str(e)}")
            return None