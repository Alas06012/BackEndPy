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
        print("LLAVE DE DEEPSEEK")
        print(Config.DEEPSEEK_APIKEY)
        # Extraer correctamente el contenido del system prompt
        system_content = system_prompt[0]['prompt_value'] if isinstance(system_prompt[0], dict) else system_prompt[0]
        
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