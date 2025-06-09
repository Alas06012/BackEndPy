from app.models.questions_model import Questions
from app.models.answers_model import Answers
from app.models.title_model import QuestionTitle
from app.models.user_model import Usuario
from flask import jsonify, request
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

        if user['user_role'] not in ['admin', 'teacher']:
            return jsonify({"message": "Insufficient permissions."}), 403

        data = request.get_json()

        required_fields = {
            "question_text": data.get("question_text"),
            "level_id": data.get("level_id"),
            "toeic_section_id": data.get("toeic_section_id"),
            "title_id": data.get("title_id"),
            "answers": data.get("answers")
        }

        # Detectar campos faltantes
        missing_fields = [field for field, value in required_fields.items() if not value]

        if missing_fields:
            return jsonify({"error": f"Missing required fields: {', '.join(missing_fields)}"}), 400

        answers = data["answers"]
        if not any(ans.get("is_correct") for ans in answers):
            return jsonify({"error": "Provide at least one correct answer."}), 400

        try:
            # Crear pregunta
            question_id = Questions.create_question(
                data["title_id"],
                data["level_id"],
                data["toeic_section_id"],
                data["question_text"]
            )

            # Crear respuestas
            for answer in answers:
                text = answer.get("text", "").strip()
                is_correct = bool(answer.get("is_correct", False))
                if text:
                    Answers.create_answer(question_id, text, is_correct)

            return jsonify({"message": "Question and answers created successfully"}), 201

        except Exception as e:
            return jsonify({"error": f"Error creating question: {str(e)}"}), 500

    #METODO CREAR QUESTIONS EN BULK
    #-----------------------------------------
    # UNICAMENTE VALIDO PARA USUARIOS ADMIN
    # 
    @staticmethod
    @jwt_required()
    def create_questions_bulk():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)

        if user['user_role'] not in ['admin', 'teacher']:
            return jsonify({"message": "Insufficient permissions."}), 403

        data = request.get_json()
        fk_title = data.get("fk_title")
        questions = data.get("questions", [])

        if not fk_title or not questions:
            return jsonify({"error": "Incomplete title or questions."}), 400

        try:
            Questions.create_questions_with_answers_bulk(fk_title, questions)
            return jsonify({"message": "Questions and answers created successfully"}), 201

        except Exception as e:
            return jsonify({"error": f"Error occurred: {str(e)}"}), 500
        
    #METODO EDITAR QUESTION 
    #--------------------
    # UNICAMENTE VALIDO PARA USUARIOS ADMIN
    #
    @staticmethod
    @jwt_required()
    def edit_question():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)

        if user['user_role'] not in ['admin', 'teacher']:
            return jsonify({"message": "Insufficient permissions."}), 403

        data = request.get_json()

        question_id = data.get('question_id')
        if not question_id:
            return jsonify({"error": "Question ID is required"}), 400

        # Mapeo correcto según tu base de datos
        field_mapping = {
            "question_text": "question_text",
            "level_id": "level_fk",
            "toeic_section_id": "toeic_section_fk",
            "title_id": "title_fk",
            "status": "status"
        }

        update_fields = {
            db_field: data[key]
            for key, db_field in field_mapping.items()
            if key in data
        }

        # Actualizar pregunta
        response = Questions.edit_question(question_id, **update_fields)

        if response != 'True':
            return jsonify({"error": "Failed to update question", "details": response}), 400

        #Actualizar respuestas
        if 'answers' in data:
            try:
                # 1. Eliminar las respuestas existentes de esta pregunta (eliminación total)
                Answers.delete_all_answers(question_id)  # Elimina todas las respuestas asociadas a la pregunta

                # 2. Insertar las nuevas respuestas
                for ans in data['answers']:
                    answer_text = ans.get('text')  # Viene del frontend
                    is_correct = ans.get('is_correct', False)
                    if answer_text:
                        Answers.create_answer(question_id, answer_text, is_correct)

            except Exception as e:
                return jsonify({"error": f"Error updating answers: {str(e)}"}), 500

        return jsonify({"message": "Question updated successfully"}), 200

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
            if not user or user.get('user_role') not in ['admin', 'teacher']:
                return jsonify({"message": "Insufficient permissions."}), 403

            # Obtener ID y nuevo estado desde el body
            data = request.get_json()
            question_id = data.get('question_id')
            new_status = data.get('status')  # Puede ser 'ACTIVE' o 'INACTIVE'

            if not question_id or new_status not in ['ACTIVE', 'INACTIVE']:
                return jsonify({"error": "Parámetros inválidos."}), 400

            # Actualizar estado
            response = Questions.delete_question(question_id, new_status)

            if response == 'True':
                return jsonify({"message": f"Question {'activated' if new_status == 'ACTIVE' else 'deactivated'} successfully."}), 200

            return jsonify({
                "error": "Failed to update question status",
                "detalle": response
            }), 400

        except Exception as e:
            return jsonify({"error": "Internal server error", "detalle": str(e)}), 500

            
    #METODO MOSTRAR TODOS LOS QUESTIONS DE UN TITLE
    #------------------------------------------------
    # UNICAMENTE VALIDO PARA USUARIOS ADMIN
    #
    @staticmethod
    @jwt_required()
    def get_questions_per_title():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)
        
        if user['user_role'] not in ['admin', 'teacher']:
            return jsonify({"message": "Insufficient permissions."}), 404
        
        # Obtener ID desde el body
        data = request.get_json()
        id_ = data.get('title_id')
        
        if not id_:
            return jsonify({"error": "Title ID is required"}), 400

        questions = Questions.get_questions_per_title(title_id=id_)
        
        # Si es un error en texto, retornamos como error
        if isinstance(questions, str):
            return jsonify({"error": "Failed to retrieve questions", "detalle": questions}), 500
        
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

            if user['user_role'] not in ['admin', 'teacher']:
                return jsonify({"message": "Insufficient permissions"}), 403

            # Cuerpo del request
            data = request.get_json() or {}
           
            # Parámetros de paginación
            try:
                page = int(data.get('page', 1))
                per_page = int(data.get('per_page', 20))
            except ValueError:
                return jsonify({"error": "Invalid pagination parameters"}), 400

            if page < 1 or per_page < 1:
                return jsonify({"error": "Pagination parameters must be ≥ 1"}), 400
            if per_page > 100:
                per_page = 100  # Limitamos el máximo de preguntas por página a 100

            # Filtros opcionales
            filters = {
                'status': data.get('status', 'Todos'),  # 'ACTIVE' por defecto
                'title_id': data.get('title_id'),
                'level_id': data.get('level_id'),
                'toeic_section_id': data.get('toeic_section_id'),
                'question_text': data.get('search_text')
            }

            # Eliminar filtros con valores nulos o vacíos
            filters = {k: v for k, v in filters.items() if v is not None and v != ''}

            # Obtener preguntas paginadas con los filtros aplicados
            paginated_results = Questions.get_paginated_questions(
                **filters,  # Expande el diccionario para pasar los filtros como parámetros
                page=page,
                per_page=per_page
            )

            if isinstance(paginated_results, str):
                return jsonify({"error": "Database error", "details": paginated_results}), 500

            response = {
                "questions": paginated_results['data'],
                "pagination": {
                    "total_items": paginated_results['total'],
                    "total_pages": paginated_results['pages'],
                    "current_page": page,
                    "items_per_page": per_page
                }
            }

            # Agregar filtros aplicados a la respuesta
            if filters:
                response["applied_filters"] = filters

            return jsonify(response), 200

        except Exception as e:
            import traceback
            print(traceback.format_exc())  # Para depurar el error en el servidor
            return jsonify({"error": "Internal server error", "details": str(e)}), 500

            

    
    
