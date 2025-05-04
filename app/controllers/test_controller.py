from app.models.test_model import Test
from app.models.title_model import QuestionTitle
from app.models.questions_model import Questions
from app.models.testdetail_model import TestDetail
from app.models.answers_model import Answers
from app.models.testdetail_model import TestDetail
from app.models.prompt_model import Prompt
from app.models.user_model import Usuario
from app.models.apideepseek_model import ApiDeepSeekModel


from flask import json, jsonify, request
from flask_jwt_extended import create_access_token, jwt_required, get_jwt_identity
from flask_jwt_extended import jwt_required, get_jwt_identity, create_access_token
import pandas as pd
import bcrypt
from app import mysql
from dotenv import load_dotenv 

# Cargar variables del archivo .env
load_dotenv()

class TestController:
    @staticmethod
    @jwt_required()
    def create_test():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)
        
        if user['user_role'] not in ['admin', 'teacher']:
            return jsonify({"message": "Permisos insuficientes"}), 403
            
        data = request.get_json()
        user_fk = data.get('user_fk')
        
        if not user_fk:
            return jsonify({"message": "ID de usuario requerido"}), 400
            
        try:
            # Iniciar transacción
            cur = mysql.connection.cursor()
        
            # Crear test
            test_id = Test.create_test(user_fk)

            # Obtener títulos aleatorios
            random_titles = Test.get_random_titles()
            
            # Asignar 4 preguntas por título
            test_details = []
            for title in random_titles:
                title_id = title["pk_title"]  # pk_title es la primera columna
            
                questions = Questions.get_random_questions_by_title(title_id)
                
                if len(questions) < 4:
                    raise Exception(f"Título {title_id} no tiene suficientes preguntas")
                
                for question in questions:
                    TestDetail.create_detail(test_id, title_id, question["pk_question"])
                    test_details.append({
                        "title_id": title_id,
                        "question_id": question["pk_question"]
                    })
            
            # Confirmar todos los cambios
            mysql.connection.commit()
            
            return jsonify({
                "message": "Test creado con preguntas",
                "data": {
                    "test_id": test_id,
                    "total_preguntas": len(test_details),
                    "detalles": test_details
                }
            }), 201
            
        except Exception as e:
            mysql.connection.rollback()
            return jsonify({"error": str(e)}), 500
        
        
        
    @staticmethod
    @jwt_required()
    def finish_test():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)

        if user['user_role'] not in ['admin', 'teacher']:
            return jsonify({"message": "Permisos insuficientes"}), 403

        data = request.get_json()
        test_id = data.get('test_id')
        # detalles = data.get('detalles', [])

        try:
            # for detalle in detalles:
                # question_id = detalle.get('question_id')
                # title_id = detalle.get('title_id')
                # user_answer_id = detalle.get('user_answer_id')

                # if not all([question_id, title_id, user_answer_id]):
                #     continue  # omitir si falta algún campo

                # TestDetail.update_answer_in_testdetails(test_id, question_id, title_id, user_answer_id)

            Test.mark_as_checking_answers(test_id)
            mysql.connection.commit()
        
            ##AQUI LOGICA PARA ARMAR JSON QUE SE ENVIARA A DEEPSEEK
            
           # Obtener datos estructurados
            test_data = TestDetail.get_all_detail(test_id)
            
            if not test_data or not test_data['data']:
                return jsonify({"error": "No se encontraron resultados"}), 404
            
            # Convertir a DataFrame
            df = pd.DataFrame(test_data['data'], columns=test_data['columns'])
            
            # Procesar como JSON
            result = []
            for title, group in df.groupby('title'):
                title_data = {
                    "title": title,
                    "title_type": group['title_type'].iloc[0],
                    "title_url": group['title_url'].iloc[0] if pd.notna(group['title_url'].iloc[0]) else None,
                    "questions": []
                }
                
                for _, row in group.iterrows():
                    question = {
                        "question_text": row['question_text'],
                        "section": row['section'] if pd.notna(row['section']) else None,
                        "level": row['level'] if pd.notna(row['level']) else None,
                        "student_answer": row['student_answer'] if pd.notna(row['student_answer']) else "No respondida",
                        "is_correct": bool(row['is_correct']) if pd.notna(row['is_correct']) else False
                    }
                    title_data["questions"].append(question)
                
                result.append(title_data)
                
                
            ##AQUI LOGICA PARA AGREGAR PROMPT A JSON QUE SE ENVIARA A DEEPSEEK
            
            system_prompt = Prompt.get_active_prompt()
            
            apiresponse = ApiDeepSeekModel.test_api(system_prompt=system_prompt, user_prompt=result)
            
            print(apiresponse)

            if not apiresponse: 
                return jsonify({
                    "error": "No hay un prompt creado para el analisis con IA"
                }), 500
            
            

            # Aquí puedes enviar 'result' a DeepSeek API
            #print(json.dumps(result, indent=2))  # Para debug
            
            return jsonify({
                "api": apiresponse
            }), 200

        except Exception as e:
            mysql.connection.rollback()
            return jsonify({"error": str(e)}), 500