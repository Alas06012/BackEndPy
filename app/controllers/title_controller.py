from app.models.questions_model import Questions
from app.models.title_model import QuestionTitle
from app.models.user_model import Usuario
from flask import jsonify, request
from flask_jwt_extended import create_access_token, jwt_required, get_jwt_identity
from flask_jwt_extended import jwt_required, get_jwt_identity, create_access_token
import bcrypt

class TitleController:
    
    #METODO CREAR STORY (question_title)
    #-----------------------------------------
    # UNICAMENTE VALIDO PARA USUARIOS ADMIN
    #
    @staticmethod
    @jwt_required()
    def create_story():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)

        if user['user_role'] not in ['admin', 'teacher']:
            return jsonify({"message": "El usuario no tiene permisos necesarios."}), 403

        data = request.get_json()
        
        title = data.get('title_name')         # 👈 correcto
        content = data.get('title_test')       # 👈 correcto
        title_type = data.get('title_type')    # 👈 correcto
        url = data.get('title_url')            # 👈 correcto

        # Validaciones básicas
        if not title or not content or not title_type:
            return jsonify({"error": "Por favor, completa todos los campos obligatorios"}), 400

        if title_type not in ['LISTENING', 'READING']:
            return jsonify({"error": "El tipo debe ser LISTENING o READING"}), 400

        if title_type == 'LISTENING' and not url:
            return jsonify({"error": "Para LISTENING, se requiere una URL de audio"}), 400

        response = QuestionTitle.create_title(title, content, title_type, url)

        if response == 'True':
            return jsonify({"message": "Título creado correctamente"}), 201
        else:
            return jsonify({
                "error": "No se pudo registrar el título",
                "details": response
            }), 400

    #METODO EDITAR TITLES 
    #--------------------
    # UNICAMENTE VALIDO PARA USUARIOS ADMIN
    #
    @staticmethod
    @jwt_required()
    def edit_title():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)

        if user['user_role'] not in ['admin', 'teacher']:
            return jsonify({"message": "El usuario no tiene permisos necesarios."}), 403

        data = request.get_json()

        id_ = data.get('id')
        title_type = data.get('title_type')
        title_url = data.get('title_url')
        status = data.get('status')

        if not id_:
            return jsonify({"error": "El ID del título es requerido"}), 400

        if title_type and title_type not in ['LISTENING', 'READING']:
            return jsonify({"error": "El tipo debe ser LISTENING o READING"}), 400

        if title_type == 'LISTENING' and not title_url:
            return jsonify({"error": "Por favor, agrega la URL del audio"}), 400

        if status and status not in ['ACTIVE', 'INACTIVE']:
            return jsonify({"error": "El estado debe ser ACTIVE o INACTIVE"}), 400

        # Usamos directamente las claves ya que el frontend envía los nombres correctos
        allowed_fields = ['title_name', 'title_test', 'title_type', 'title_url', 'status']
        update_fields = {field: data[field] for field in allowed_fields if field in data}

        response = QuestionTitle.edit_title(id_, **update_fields)

        if status == 'INACTIVE':
            QuestionTitle.deactivate_questions_per_title(title_id=id_)
        elif status == 'ACTIVE':
            QuestionTitle.activate_questions_per_title(title_id=id_)

        if response == 'True':
            return jsonify({"message": "Encabezado actualizado correctamente"}), 200
        else:
            return jsonify({"error": "No se pudo actualizar el encabezado", "details": response}), 400

    
    #METODO BORRAR TITLES
    #----------------------------------------------
    # Desactiva un título y sus preguntas asociadas.
    #  Solo accesible por usuarios con rol 'admin'.
    #
    @staticmethod
    @jwt_required()
    def deactivate_title(): 
        try:
            current_user_id = get_jwt_identity()
            user = Usuario.get_user_by_id(current_user_id)

            # Verificación de permisos
            if not user or user.get('user_role') not in ['admin', 'teacher']:
                return jsonify({"message": "El usuario no tiene permisos necesarios."}), 403

            # Obtener ID desde el body
            data = request.get_json()
            id_ = data.get('id')

            if not id_:
                return jsonify({"error": "El ID del título es requerido."}), 400

            # Inactivar título y preguntas relacionadas
            success_title = QuestionTitle.delete_title(id_)
            success_questions = QuestionTitle.deactivate_questions_per_title(title_id=id_)

            if success_title == 'True' and success_questions == 'True':
                return jsonify({"message": "Encabezado y preguntas desactivados correctamente."}), 200

            return jsonify({
                "error": "No se pudo desactivar el encabezado o sus preguntas.",
                "detalle": {
                    "encabezado": success_title,
                    "preguntas": success_questions
                }
            }), 400

        except Exception as e:
            return jsonify({"error": "Error interno del servidor", "detalle": str(e)}), 500
        
        
        
    @staticmethod
    @jwt_required()
    def get_filtered_titles():
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
            status = data.get('status', 'Todos')
            title_type = data.get('title_type')  
            title_name = data.get('title_name')
            print("title_name:", data.get('title_name'))
 
            # Validación de paginación
            if page < 1 or per_page < 1:
                return jsonify({"error": "Los parámetros de paginación deben ser ≥ 1"}), 400
            if per_page > 100:
                per_page = 100

            # Llamar al modelo
            paginated_results = QuestionTitle.get_paginated_titles(
                title_name = title_name,
                status = status,
                title_type = title_type,
                page = page,
                per_page = per_page
            )

            if isinstance(paginated_results, str):
                return jsonify({"error": "Error en la base de datos", "details": paginated_results}), 500

            # Construcción de la respuesta
            response = {
                "titles": paginated_results['data'],
                "pagination": {
                    "total_items": paginated_results['total'],
                    "total_pages": paginated_results['pages'],
                    "current_page": page,
                    "items_per_page": per_page
                }
            }

            # Filtros aplicados
            if title_type:
                response["applied_filters"] = {"title_type": title_type}

            return jsonify(response), 200

        except Exception as e:
            return jsonify({"error": "Error interno", "details": str(e)}), 500
        
        

    
    
