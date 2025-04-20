from app.models.questions_model import Questions
from app.models.answers_model import Answers
from app.models.title_model import QuestionTitle
from app.models.user_model import Usuario
from flask import jsonify, request
from flask_jwt_extended import create_access_token, jwt_required, get_jwt_identity
from flask_jwt_extended import jwt_required, get_jwt_identity, create_access_token
import bcrypt

class QuestionsController:
    
    #METODO CREAR QUESTIONS
    #-----------------------------------------
    # UNICAMENTE VALIDO PARA USUARIOS ADMIN
    #
    @staticmethod
    @jwt_required()
    def create_question_with_answers():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)

        if user['user_role'] != 'admin':
            return jsonify({"message": "El usuario no tiene permisos necesarios."}), 403

        data = request.get_json()
        fk_title = data.get("fk_title")
        question_text = data.get("question_text")
        question_type_fk = data.get("question_type_fk")
        question_level_fk = data.get("question_level_fk")
        answers = data.get("answers", [])

        if not all([fk_title, question_text, question_type_fk, question_level_fk]) or not answers:
            return jsonify({"error": "Datos incompletos para la creación"}), 400

        # Crear pregunta y respuestas
        try:
            question_id = Questions.create_question(fk_title, question_level_fk, question_text, question_type_fk)

            for answer in answers:
                text = answer.get("text")
                is_correct = answer.get("is_correct", False)
                if text:
                    Answers.create_answer(question_id, text, is_correct)

            return jsonify({"message": "Pregunta y respuestas creadas exitosamente"}), 201

        except Exception as e:
            return jsonify({"error": f"Ocurrió un error: {str(e)}"}), 500
        
        
    #METODO CREAR QUESTIONS EN BULK
    #-----------------------------------------
    # UNICAMENTE VALIDO PARA USUARIOS ADMIN
    # 
    @staticmethod
    @jwt_required()
    def create_questions_bulk():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)

        if user['user_role'] != 'admin':
            return jsonify({"message": "El usuario no tiene permisos necesarios."}), 403

        data = request.get_json()
        fk_title = data.get("fk_title")
        questions = data.get("questions", [])

        if not fk_title or not questions:
            return jsonify({"error": "El título o las preguntas están incompletas"}), 400

        try:
            Questions.create_questions_with_answers_bulk(fk_title, questions)
            return jsonify({"message": "Preguntas y respuestas creadas exitosamente"}), 201

        except Exception as e:
            return jsonify({"error": f"Ocurrió un error: {str(e)}"}), 500
        
    
    
    
    #METODO EDITAR QUESTION 
    #--------------------
    # UNICAMENTE VALIDO PARA USUARIOS ADMIN
    #
    @staticmethod
    @jwt_required()
    def edit_question():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)
        
        if user['user_role'] != 'admin':
            return jsonify({"message": "El usuario no tiene permisos necesarios."}), 403

        data = request.get_json()
        id_ = data.get('question_id')
        status = data.get('status')
        
        if not id_ :
            return jsonify({"error": "El ID de la pregunta es requerido"}), 400
        
        if status and status not in['INACTIVE','ACTIVE']:
            return jsonify({"error": "El estado solo puede ser ACTIVE o INACTIVE"}), 400

        
        # Mapeo del JSON recibido a los nombres de columnas reales
        field_mapping = {
            "content": "question_text",
            "status": "status",
            "level_fk": "level_fk",
            "toeic_section_fk": "toeic_section_fk"
        }

        # Construir diccionario solo con campos presentes en el JSON
        update_fields = {
            db_field: data[key]
            for key, db_field in field_mapping.items()
            if key in data
        }

        response = Questions.edit_question(id_, **update_fields)
    
        if response == 'True':
            return jsonify({"message": "Encabezado actualizado correctamente"}), 200
        else:
            return jsonify({"error": "No se pudo actualizar el encabezado", "details": response}), 400
    
    
    
    #METODO BORRAR QUESTION
    #----------------------------------------------
    # Desactiva una pregunta
    #  Solo accesible por usuarios con rol 'admin'.
    #
    @staticmethod
    @jwt_required()
    def deactivate_question(): 
        try:
            current_user_id = get_jwt_identity()
            user = Usuario.get_user_by_id(current_user_id)

            # Verificación de permisos
            if not user or user.get('user_role') != 'admin':
                return jsonify({"message": "El usuario no tiene permisos necesarios."}), 403

            # Obtener ID desde el body
            data = request.get_json()
            id_ = data.get('question_id')

            if not id_:
                return jsonify({"error": "El ID de la pregunta es requerido."}), 400

            # Inactivar pregunta
            response = Questions.delete_question(id_)

            if response == 'True':
                return jsonify({"message": "Pregunta desactivada correctamente."}), 200

            return jsonify({
                "error": "No se pudo desactivar la pregunta.",
                "detalle": {
                    "pregunta": response
                }
            }), 400

        except Exception as e:
            return jsonify({"error": "Error interno del servidor", "detalle": str(e)}), 500
        
    
    
    #METODO MOSTRAR TODOS LOS QUESTIONS DE UN TITLE
    #------------------------------------------------
    # UNICAMENTE VALIDO PARA USUARIOS ADMIN
    #
    @staticmethod
    @jwt_required()
    def get_questions_per_title():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)
        
        if user['user_role'] != 'admin':
            return jsonify({"message": "El usuario no tiene permisos necesarios."}), 404
        
        # Obtener ID desde el body
        data = request.get_json()
        id_ = data.get('title_id')
        
        if not id_:
            return jsonify({"error": "El ID del title es requerido."}), 400

        questions = Questions.get_questions_per_title(title_id=id_)
        
        # Si es un error en texto, retornamos como error
        if isinstance(questions, str):
            return jsonify({"error": "No se pudieron obtener las preguntas", "detalle": questions}), 500
        
        # Devolver usuarios en formato JSON
        return jsonify({"preguntas_activas": questions}), 200
    
    
    
    # METODO GET_FILTERED_QUESTIONS
    # Filtrado por body: { "page": 1, "per_page": 20, "status": "ACTIVE", "title_id": 2 }
    @staticmethod
    @jwt_required()
    def get_filtered_questions():
        try:
            current_user_id = get_jwt_identity()
            user = Usuario.get_user_by_id(current_user_id)
            if user['user_role'] != 'admin':
                return jsonify({"message": "Acceso denegado: Se requieren privilegios de administrador"}), 403

            # Cuerpo del request
            data = request.get_json() or {}

            # Parámetros de paginación
            try:
                page = int(data.get('page', 1))
                per_page = int(data.get('per_page', 20))
            except ValueError:
                return jsonify({"error": "Parámetros de paginación inválidos"}), 400

            if page < 1 or per_page < 1:
                return jsonify({"error": "Los parámetros de paginación deben ser ≥ 1"}), 400
            if per_page > 100:
                per_page = 100

            # Filtros opcionales
            status = data.get('status', 'ACTIVE')
            title_id = data.get('title_id')
            level_id = data.get('level_id')
            toeic_section_id = data.get('toeic_section_id')

            # Obtener preguntas paginadas
            paginated_results = Questions.get_paginated_questions(
                status=status,
                title_id=title_id,
                level_id=level_id,
                toeic_section_id=toeic_section_id,
                page=page,
                per_page=per_page
            )

            if isinstance(paginated_results, str):
                return jsonify({"error": "Error en la base de datos", "details": paginated_results}), 500

            response = {
                "questions": paginated_results['data'],
                "pagination": {
                    "total_items": paginated_results['total'],
                    "total_pages": paginated_results['pages'],
                    "current_page": page,
                    "items_per_page": per_page
                }
            }

            # Agregar filtros usados
            filters = {}
            if title_id: filters['title_id'] = title_id
            if level_id: filters['level_id'] = level_id
            if toeic_section_id: filters['toeic_section_id'] = toeic_section_id
            if filters:
                response["applied_filters"] = filters

            return jsonify(response), 200

        except Exception as e:
            import traceback
            print(traceback.format_exc())
            return jsonify({"error": "Error interno", "details": str(e)}), 500
        
        

    
    
