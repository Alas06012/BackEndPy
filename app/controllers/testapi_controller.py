from flask import jsonify, request
from flask_jwt_extended import create_access_token, jwt_required, get_jwt_identity
from flask_jwt_extended import jwt_required, get_jwt_identity, create_access_token
import bcrypt
from app import mysql
# Please install OpenAI SDK first: `pip3 install openai`
from openai import OpenAI

class TestApiController:
    @staticmethod
    def test_api():
        client = OpenAI(api_key="<>", base_url="https://api.deepseek.com")

        try:
            response = client.chat.completions.create(
                model="deepseek-chat",
                messages=[
                    {"role": "system", "content": "You are a helpful assistant"},
                    {"role": "user", "content": "Hello"},
                ],
                stream=False
            )
            print(response.choices[0].message.content)
            return jsonify({"response": response.choices[0].message.content}), 200
        except Exception as e:
            return jsonify({"error": str(e)}), 500