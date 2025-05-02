from app.models.test_model import Test
from app.models.title_model import QuestionTitle
from app.models.questions_model import Questions
from app.models.testdetail_model import TestDetail
from app.models.answers_model import Answers
from app.models.testdetail_model import TestDetail
from app.models.user_model import Usuario
from flask import jsonify, request
from flask_jwt_extended import create_access_token, jwt_required, get_jwt_identity
from flask_jwt_extended import jwt_required, get_jwt_identity, create_access_token
import bcrypt
from app import mysql

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
        detalles = data.get('detalles', [])

        try:
            for detalle in detalles:
                question_id = detalle.get('question_id')
                title_id = detalle.get('title_id')
                user_answer_id = detalle.get('user_answer_id')

                if not all([question_id, title_id, user_answer_id]):
                    continue  # omitir si falta algún campo

                TestDetail.update_answer_in_testdetails(test_id, question_id, title_id, user_answer_id)

            Test.mark_as_checking_answers(test_id)
            mysql.connection.commit()
            
            
            
            ##AQUI LOGICA PARA ARMAR JSON QUE SE ENVIARA A DEEPSEEK
            
            
            
            return jsonify({"message": "Examen finalizado correctamente."}), 200

        except Exception as e:
            mysql.connection.rollback()
            return jsonify({"error": str(e)}), 500