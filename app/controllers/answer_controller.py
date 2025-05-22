from app.models.questions_model import Questions
from app.models.answers_model import Answers
from app.models.title_model import QuestionTitle
from app.models.user_model import Usuario
from flask import jsonify, request
from flask_jwt_extended import create_access_token, jwt_required, get_jwt_identity
from flask_jwt_extended import jwt_required, get_jwt_identity, create_access_token
import bcrypt

class AnswersController:
    
    #METODO CREAR ANSWERS
    #-----------------------------------------
    # UNICAMENTE VALIDO PARA USUARIOS ADMIN
    #
    @staticmethod
    @jwt_required()
    def create_answers():
        try:
            current_user_id = get_jwt_identity()
            user = Usuario.get_user_by_id(current_user_id)

            if user['user_role'] not in ['admin', 'teacher'] :
                return jsonify({"message": "El usuario no tiene permisos necesarios."}), 403

            data = request.get_json()
            question_id = data.get("question_id")
            text = data.get("text")
            is_correct = data.get("is_correct")
            
            if question_id is None or not text or is_correct is None:
                return jsonify({"error": "Datos incompletos para la creación"}), 400
        
            response = Answers.create_answer(question_id, text, is_correct)

            if response == 'True':
                return jsonify({"message": "Opción de respuesta agregada correctamente"}), 200
            else:
                return jsonify({"error": "No se pudo agregar la respuesta", "details": response}), 400

        except Exception as e:
            return jsonify({"error": f"Ocurrió un error: {str(e)}"}), 500
        
        
    #METODO CREAR ANSWERS EN BULK
    #-----------------------------------------
    # UNICAMENTE VALIDO PARA USUARIOS ADMIN
    # 
    @staticmethod
    @jwt_required()
    def create_bulk_answers():
        try:
            current_user_id = get_jwt_identity()
            user = Usuario.get_user_by_id(current_user_id)

            if user['user_role'] not in ['admin', 'teacher']:
                return jsonify({"message": "El usuario no tiene permisos necesarios."}), 403

            data = request.get_json()
            answers_list = data.get("answers")  # Espera una lista de diccionarios

            if not answers_list or not isinstance(answers_list, list):
                return jsonify({"error": "Formato inválido. Se esperaba una lista de respuestas."}), 400

            # Validación de cada respuesta
            for answer in answers_list:
                question_id = answer.get("question_id")
                text = answer.get("text")
                is_correct = answer.get("is_correct")
                
                if question_id is None or not text or is_correct is None:
                    return jsonify({"error": f"Datos incompletos en la respuesta: {answer}"}), 400

            # Llamada al modelo para bulk insert
            response = Answers.create_bulk_answers(answers_list)

            if response == 'True':
                return jsonify({"message": f"{len(answers_list)} respuestas agregadas correctamente"}), 200
            else:
                return jsonify({"error": "No se pudieron agregar las respuestas", "details": response}), 400

        except Exception as e:
            return jsonify({"error": f"Ocurrió un error: {str(e)}"}), 500
        
    
    
    
    #METODO EDITAR QUESTION 
    #--------------------
    # UNICAMENTE VALIDO PARA USUARIOS ADMIN
    #
    @staticmethod
    @jwt_required()
    def edit_answer():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)
        
        if user['user_role'] not in ['admin', 'teacher']:
            return jsonify({"message": "El usuario no tiene permisos necesarios."}), 403

        data = request.get_json()
        answer_id = data.get('answer_id') 
        status = data.get('status')
        
        if not answer_id:
            return jsonify({"error": "El ID de la respuesta es requerido"}), 400
        
        if status and status not in['INACTIVE','ACTIVE']:
            return jsonify({"error": "El estado solo puede ser ACTIVE o INACTIVE"}), 400

        # Mapeo del JSON recibido a los nombres de columnas reales en la DB
        field_mapping = {
            "question_id": "question_fk",  
            "text": "answer_text",        # Columna answer_text en DB
            "is_correct": "is_correct",    # Booleano
            "status": "status", 
        }

        # Construir diccionario solo con campos presentes en el JSON
        update_fields = {
            db_field: data[key]
            for key, db_field in field_mapping.items()
            if key in data
        }

        # Validación adicional para is_correct (debe ser booleano si está presente)
        if 'is_correct' in data and not isinstance(data['is_correct'], bool):
            return jsonify({"error": "is_correct debe ser true o false"}), 400

        response = Answers.edit_answer(answer_id, **update_fields)

        if response == 'True':
            return jsonify({"message": "Respuesta actualizada correctamente"}), 200
        else:
            return jsonify({"error": "No se pudo actualizar la respuesta", "details": response}), 400
    
    
    
    #METODO BORRAR QUESTION
    #----------------------------------------------
    # Desactiva una pregunta
    #  Solo accesible por usuarios con rol 'admin'.
    #
    @staticmethod
    @jwt_required()
    def deactivate_answer(): 
        try:
            current_user_id = get_jwt_identity()
            user = Usuario.get_user_by_id(current_user_id)

            if not user or user.get('user_role') not in ['admin', 'teacher']:
                return jsonify({"message": "El usuario no tiene permisos necesarios."}), 403

            data = request.get_json()
            id_ = data.get('answer_id')

            if not id_:
                return jsonify({"error": "El ID de la respuesta es requerido."}), 400

            # Inactivar respuesta (llamada al modelo)
            response = Answers.delete_answer(id_)

            if response == 'True':
                return jsonify({"message": "Respuesta desactivada correctamente."}), 200

            return jsonify({
                "error": "No se pudo desactivar la respuesta.",
                "detalle": {
                    "respuesta": response
                }
            }), 400

        except Exception as e:
            return jsonify({"error": "Error interno del servidor", "detalle": str(e)}), 500
        
        
    
    #METODO MOSTRAR TODOS LOS ANSWERS DE UN QUESTION
    #------------------------------------------------
    # UNICAMENTE VALIDO PARA USUARIOS ADMIN
    #
    @staticmethod
    @jwt_required()
    def get_questions_per_title():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)
        
        if user['user_role'] not in ['admin', 'teacher']:
            return jsonify({"message": "El usuario no tiene permisos necesarios."}), 404
        
        # Obtener ID desde el body
        data = request.get_json()
        id_ = data.get('question_id')
        
        if not id_:
            return jsonify({"error": "El ID de la pregunta es requerido."}), 400

        answers = Answers.get_answers_per_question(question_id=id_)
        
        # Si es un error en texto, retornamos como error
        if isinstance(answers, str):
            return jsonify({"error": "No se pudieron obtener las respuestas", "detalle": answers}), 500
        
        # Devolver usuarios en formato JSON
        return jsonify({"respuestas_activas": answers}), 200
    
    
    # METODO GET_FILTERED_ANSWERS
    # -----------------------------------------
    # Filtrado por body: { "page": 1, "per_page": 20, "status": "ACTIVE", "question_id": 5 }
    #
    @staticmethod
    @jwt_required()
    def get_filtered_answers():
        try:
            # Validación de permisos
            current_user_id = get_jwt_identity()
            user = Usuario.get_user_by_id(current_user_id)
            if user['user_role'] not in ['admin', 'teacher']:
                return jsonify({"message": "Acceso denegado: Usuario sin privilegios suficientes"}), 403

            # Parámetros del body con valores por defecto
            data = request.get_json() or {}
            page = data.get('page', 1)
            per_page = data.get('per_page', 20)
            status = data.get('status', 'ACTIVE')
            question_id = data.get('question_id')  # Opcional

            # Validación
            if page < 1 or per_page < 1:
                return jsonify({"error": "Los parámetros de paginación deben ser ≥ 1"}), 400
            if per_page > 100:  # Límite máximo por seguridad
                per_page = 100

            # Obtener datos
            paginated_results = Answers.get_paginated_answers(
                status=status,
                question_id=question_id,  # Nuevo filtro
                page=page,
                per_page=per_page
            )

            if isinstance(paginated_results, str):
                return jsonify({"error": "Error en la base de datos", "details": paginated_results}), 500

            # Respuesta estructurada
            response = {
                "answers": paginated_results['data'],
                "pagination": {
                    "total_items": paginated_results['total'],
                    "total_pages": paginated_results['pages'],
                    "current_page": page,
                    "items_per_page": per_page
                }
            }
            
            # Agregar filtros aplicados si es relevante
            if question_id:
                response["applied_filters"] = {"question_id": question_id}

            return jsonify(response), 200

        except Exception as e:
            return jsonify({"error": "Error interno", "details": str(e)}), 500
        
        

    
    
