from app.models.test_model import Test
from app.models.title_model import QuestionTitle
from app.models.questions_model import Questions
from app.models.testdetail_model import TestDetail
from app.models.answers_model import Answers
from app.models.testdetail_model import TestDetail
from app.models.prompt_model import Prompt
from app.models.user_model import Usuario
from app.models.apideepseek_model import ApiDeepSeekModel
from app.models.strengths_model import Strengths
from app.models.weaknesses_model import Weaknesses
from app.models.recommendations_model import Recommendations
from app.models.userlevel_history_model import UserLevelhistory


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
        try:
            # Validaciones iniciales
            current_user_id = get_jwt_identity()
            user = Usuario.get_user_by_id(current_user_id)
            
            if user['user_role'] not in ['admin', 'teacher']:
                return jsonify({
                    "success": False,
                    "message": "Permisos insuficientes"
                }), 403

            data = request.get_json()
            test_id = data.get('test_id')
            # detalles = data.get('detalles', [])
            
            # if not test_id:
            #     return jsonify({
            #         "success": False,
            #         "message": "El campo 'test_id' es requerido"
            #     }), 400

            # Iniciar transacción
            mysql.connection.begin()
            cursor = mysql.connection.cursor()

            try:
                ##1. Actualizar respuestas del test
                # for detalle in detalles:
                #     if not all(k in detalle for k in ['question_id', 'title_id', 'user_answer_id']):
                #         continue
                #     TestDetail.update_answer_in_testdetails(
                #         test_id, 
                #         detalle['question_id'],
                #         detalle['title_id'],
                #         detalle['user_answer_id']
                #     )

                # 2. Marcar test como "en revisión"
                Test.mark_as_checking_answers(test_id)

                # 3. Obtener datos para IA
                test_data = TestDetail.get_all_detail(test_id)
                if not test_data or not test_data['data']:
                    raise ValueError("No se encontraron resultados para evaluar")

                # 4. Construir prompt de usuario para IA
                df = pd.DataFrame(test_data['data'], columns=test_data['columns'])
                user_prompt = TestController._build_ia_prompt(df)

                # 5. Consultar en BD prompt de sistema para IA
                system_prompt = Prompt.get_active_prompt()
                
                # 6. Llamar a la IA
                #apiresponse = ApiDeepSeekModel.test_api(system_prompt=system_prompt, user_prompt=user_prompt)

                #JSON PARA PRUEBAS
                apiresponse = {'mcer_level': 'B1', 'toeic_score': 720, 'passed': True, 'strengths': ["The student demonstrates a good understanding of basic and intermediate level questions, particularly in reading comprehension where they correctly identified the type of internships offered and the departments involved. Their ability to grasp details from the listening section, such as the time frame and the candidate's aspirations, also indicates a solid foundation in listening comprehension."], 'weaknesses': ['The student missed a straightforward question about the application deadline in the reading section, which was an A2 level question, suggesting a need for more attention to detail. Additionally, they incorrectly answered a B1 level question in the listening section about what the interviewer asked, indicating potential difficulties with understanding specific questions or nuances in spoken English.'], 'recommendations': ['To improve, the student should practice more with reading comprehension exercises focusing on detail-oriented questions to enhance their ability to catch specific information. For listening comprehension, engaging with a variety of audio materials, especially those involving interviews or conversations, can help in better understanding the context and nuances of spoken English. Additionally, taking timed practice tests can aid in improving both speed and accuracy in identifying correct answers.']}
                
                if not apiresponse:
                    raise ValueError("La IA no generó una respuesta válida")

                # 7. Guardar resultados
                Test.save_evaluation_results(test_id=test_id, user_id=current_user_id, ai_response=apiresponse)
                mysql.connection.commit()

                return jsonify({
                    "success": True,
                    "message": "Examen evaluado y guardado correctamente",
                    "data": {
                        "mcer_level": apiresponse.get('mcer_level'),
                        "approved": apiresponse.get('passed')
                    }
                }), 200

            except Exception as e:
                mysql.connection.rollback()
                return jsonify({
                    "success": False,
                    "message": f"Error al procesar el examen: {str(e)}"
                }), 500

        except Exception as e:
            return jsonify({
                "success": False,
                "message": f"Error inesperado: {str(e)}"
            }), 500



    @staticmethod
    def _build_ia_prompt(df):
        #Método auxiliar para construir el prompt de usuario para IA
        user_prompt = []
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
            
            user_prompt.append(title_data)
        
        return user_prompt