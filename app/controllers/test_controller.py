from app.models.test_model import Test
from app.models.title_model import QuestionTitle
from app.models.questions_model import Questions
from app.models.testdetail_model import TestDetail
from app.models.answers_model import Answers
from app.models.test_comments_model import TestCommentsModel
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
import time
import logging

# Configuración básica para Cloud Logging
logging.basicConfig(level=logging.INFO)  # O WARNING/DEBUG/ERROR según se necesite
logger = logging.getLogger(__name__)

# Cargar variables del archivo .env
load_dotenv()

class TestController:
    @staticmethod
    @jwt_required()
    def create_test():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)
        
        if user['user_role'] not in ['admin' ,'student']:
            return jsonify({"message": "Permisos insuficientes"}), 403
            
        data = request.get_json()
        user_fk = user['pk_user']
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
            current_user_id = get_jwt_identity()
            user = Usuario.get_user_by_id(current_user_id)

            if user['user_role'] not in ['admin', 'teacher', 'student']:
                return jsonify({
                    "success": False,
                    "message": "Permisos insuficientes"
                }), 403

            data = request.get_json()
            test_id = data.get('test_id')
            detalles = data.get('detalles', [])
        
            if not test_id:
                return jsonify({
                    "success": False,
                    "message": "El campo 'test_id' es requerido"
                }), 400

            mysql.connection.begin()
            cursor = mysql.connection.cursor()

            try:
                # 1. Actualizar respuestas del test
                for detalle in detalles:
                    if not all(k in detalle for k in ['question_id', 'title_id', 'user_answer_id']):
                        continue
                    TestDetail.update_answer_in_testdetails(
                        test_id, 
                        detalle['question_id'],
                        detalle['title_id'],
                        detalle['user_answer_id']
                    )

                # 2. Marcar test como "en revisión"
                Test.mark_as_checking_answers(test_id)

                # 3. Obtener datos para IA
                test_data = TestDetail.get_all_detail(test_id)
                if not test_data or not test_data['data']:
                    raise ValueError("No se encontraron resultados para evaluar")

                df = pd.DataFrame(test_data['data'], columns=test_data['columns'])
                
                # 3.1 Obtener prompts para peticion 
                user_prompt = TestController._build_ia_prompt(df)
                system_prompt = Prompt.get_active_prompt()

                # 4. Reintento de llamada a la IA hasta 3 veces
                max_retries = 3
                retry_delay = 2  # segundos entre intentos
                apiresponse = None

                for attempt in range(max_retries):
                    apiresponse = ApiDeepSeekModel.test_api(system_prompt=system_prompt, user_prompt=user_prompt)
                    print(apiresponse)
                    logger.info(f"Respuesta intento {attempt + 1}: {apiresponse}")
                    if TestController._is_valid_ia_response(apiresponse):
                        break
                    apiresponse = None  # asegurarse de que si no es válida, se descarte
                    time.sleep(retry_delay)

                logger.info(f"Respuesta final: {apiresponse}")

                if not apiresponse or not isinstance(apiresponse, dict):
                    Test.mark_as_failed(test_id)
                    return jsonify({
                        "success": False,
                        "message": "La IA no generó una respuesta válida tras varios intentos"
                    }), 500

                # 5. Guardar resultados
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
    @jwt_required()
    def retry_failed_test():
        try:
            current_user_id = get_jwt_identity()
            user = Usuario.get_user_by_id(current_user_id)

            if user['user_role'] not in ['admin', 'teacher']:
                return jsonify({
                    "success": False,
                    "message": "Solo administradores o docentes pueden reintentar una evaluación"
                }), 403

            data = request.get_json()
            test_id = data.get('test_id')

            if not test_id:
                return jsonify({
                    "success": False,
                    "message": "El campo 'test_id' es requerido"
                }), 400

            # 1. Verificar si el test está marcado como FAILED
            test = Test.get_test_by_id(test_id)
            if not test or (test['status'] != 'FAILED' and test['status'] != 'IN_PROGRESS'):
                return jsonify({
                    "success": False,
                    "message": "El examen no está en estado 'FAILED' o no existe"
                }), 400

            mysql.connection.begin()
            cursor = mysql.connection.cursor()

            # 2. Obtener datos del test para enviar a la IA
            test_data = TestDetail.get_all_detail(test_id)
            if not test_data or not test_data['data']:
                raise ValueError("No se encontraron resultados para evaluar")

            df = pd.DataFrame(test_data['data'], columns=test_data['columns'])

            user_prompt = TestController._build_ia_prompt(df)
            system_prompt = Prompt.get_active_prompt()

            # 3. Reintento de llamada a la IA
            max_retries = 3
            retry_delay = 2
            apiresponse = None

            for attempt in range(max_retries):
                apiresponse = ApiDeepSeekModel.test_api(system_prompt=system_prompt, user_prompt=user_prompt)
                if TestController._is_valid_ia_response(apiresponse):
                    break
                apiresponse = None  # asegurarse de que si no es válida, se descarte
                time.sleep(retry_delay)

            if not apiresponse or not isinstance(apiresponse, dict):
                Test.mark_as_failed(test_id)
                return jsonify({
                    "success": False,
                    "message": "La IA no generó una respuesta válida tras reintento"
                }), 500

            # 4. Guardar resultados y cambiar estado del test
            Test.save_evaluation_results(test_id=test_id, user_id=current_user_id, ai_response=apiresponse)
            mysql.connection.commit()

            return jsonify({
                "success": True,
                "message": "Examen reevaluado y actualizado correctamente",
                "data": {
                    "mcer_level": apiresponse.get('mcer_level'),
                    "approved": apiresponse.get('passed')
                }
            }), 200

        except Exception as e:
            mysql.connection.rollback()
            return jsonify({
                "success": False,
                "message": f"Error al reintentar evaluación: {str(e)}"
            }), 500

    
    

    @staticmethod
    @jwt_required()
    def get_test_by_id():
        try:
            # Validaciones iniciales
            current_user_id = get_jwt_identity()
            user = Usuario.get_user_by_id(current_user_id)
            
            if user['user_role'] not in ['admin', 'teacher', 'student']:
                return jsonify({
                    "success": False,
                    "message": "Permisos insuficientes"
                }), 403
                
            req = request.get_json()
            test_id = req.get('test_id')
            
            if not test_id or not str(test_id).isdigit():
                return jsonify({"success": False, "message": "ID del test inválido"}), 400

            data = TestDetail.get_by_test_id(test_id)            
            exam_structure = TestController.build_exam_structure(test_id, data)

            return jsonify(exam_structure), 200

        except Exception as e:
            return jsonify({"error": str(e)}), 500
        
        
              
    @staticmethod
    @jwt_required()
    def get_filtered_tests():
        try:
            current_user_id = get_jwt_identity()
            user = Usuario.get_user_by_id(current_user_id)
         
            if user['user_role'] not in ['admin', 'teacher','student']:
                return jsonify({
                    "success": False,
                    "message": "Permisos insuficientes"
                }), 403

            data = request.get_json() or {}
            
            
            page = data.get("page", 1)
            per_page = data.get("per_page", 20)

            filters = {
            "user_email": data.get("user_email"),
            "user_name": data.get("user_name"),
            "user_lastname": data.get("user_lastname"),
            "test_passed": data.get("test_passed"),
            "level_name": data.get("level_name"),
            "status": data.get("status"),
             "user_role": user['user_role'],
             "user_id": user['pk_user']
        }
            results = Test.get_paginated_tests(filters=filters, page=page, per_page=per_page)
            if isinstance(results, str):
                return jsonify({"error": "Database error", "details": results}), 500

            response = {
                "tests": results["data"],
                "pagination": {
                    "total_items": results["total"],
                    "total_pages": results["pages"],
                    "current_page": page,
                    "items_per_page": per_page
                },
                "applied_filters": {k: v for k, v in filters.items() if v is not None}
            }

            return jsonify(response), 200

        except Exception as e:
            return jsonify({"error": "Internal server error", "details": str(e)}), 500
        
        
        
    @staticmethod
    @jwt_required()
    def get_test_analysis():
        try:
            current_user_id = get_jwt_identity()
            user = Usuario.get_user_by_id(current_user_id)

            if not user:
                return jsonify({"message": "Usuario no encontrado"}), 404
            
            
            if user['user_role'] not in ['admin', 'teacher','student']:
                return jsonify({
                    "success": False,
                    "message": "Permisos insuficientes"
                }), 403
                
            data = request.get_json()
            test_id = data.get("test_id")
        
            
            if not test_id or not str(test_id).isdigit():
                return jsonify({"success": False, "message": "ID del test inválido"}), 400
            
            result = Test.get_test_analysis_by_id(test_id)

            if isinstance(result, str):
                return jsonify({"error": "Database error", "details": result}), 500

            return jsonify(result), 200

        except Exception as e:
            return jsonify({"error": "Internal server error", "details": str(e)}), 500



        
    #------------------------------------------------------------------
    #
    #      METODOS AUXILIARES MANEJO DE JSONs
    #
    #------------------------------------------------------------------
    
    
    #Funcion auxiliar para validar que la respuesta de la api deepseek sea la esperada
    @staticmethod
    def _is_valid_ia_response(response):
        if not isinstance(response, dict):
            return False

        required_keys = {
            'mcer_level': str,
            'toeic_score': int,
            'passed': bool,
            'strengths': list,
            'weaknesses': list,
            'recommendations': list
        }

        for key, expected_type in required_keys.items():
            if key not in response or not isinstance(response[key], expected_type):
                return False

        return True
    
    
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
    
    
    
    @staticmethod
    def build_exam_structure(test_id, data):
        exam_structure = {
            "test_id": test_id,
            "sections": []
        }

        # Mapa para acceso rápido
        section_map = {}

        for row in data:
            # Clave única para la sección
            section_key = f"{row['section_type']}|{row['section_desc']}"

            # Obtener o crear la sección
            if section_key not in section_map:
                section_data = {
                    "section_type": row['section_type'],
                    "section_desc": row['section_desc'],
                    "titles": [],
                    "_titles_map": {}  # mapa interno para acelerar búsqueda de títulos
                }
                section_map[section_key] = section_data
                exam_structure["sections"].append(section_data)
            else:
                section_data = section_map[section_key]

            # Obtener o crear el título
            titles_map = section_data["_titles_map"]
            if row['title_id'] not in titles_map:
                title_data = {
                    "title_id": row['title_id'],
                    "title_name": row['title_name'],
                    "title_test": row['title_test'],
                    "title_type": row['title_type'],
                    "title_url": row['title_url'],
                    "questions": [],
                    "_questions_map": {}  # mapa interno para acelerar búsqueda de preguntas
                }
                titles_map[row['title_id']] = title_data
                section_data["titles"].append(title_data)
            else:
                title_data = titles_map[row['title_id']]

            # Obtener o crear la pregunta
            questions_map = title_data["_questions_map"]
            if row['question_id'] not in questions_map:
                question_data = {
                    "question_id": row['question_id'],
                    "question_text": row['question_text'],
                    "selected_answer_id": row['selected_answer_id'],
                    "is_selected_correct": None,
                    "answers": []
                }
                questions_map[row['question_id']] = question_data
                title_data["questions"].append(question_data)
            else:
                question_data = questions_map[row['question_id']]

            # Añadir respuesta
            is_selected = row['answer_id'] == row['selected_answer_id']
            question_data["answers"].append({
                "answer_id": row['answer_id'],
                "answer_text": row['answer_text'],
                "is_correct": row['is_correct'],
                "is_selected": is_selected
            })

            # Evaluar si la respuesta seleccionada es la correcta
            if is_selected:
                question_data["is_selected_correct"] = bool(row['is_correct'])

        # Limpieza final: eliminar los mapas internos
        for section in exam_structure["sections"]:
            for title in section["titles"]:
                del title["_questions_map"]
            del section["_titles_map"]

        return exam_structure
