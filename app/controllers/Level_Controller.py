from app.models.Level_model import LevelModel as Level
from app.models.user_model import Usuario
from flask import jsonify, request
from flask_jwt_extended import jwt_required, get_jwt_identity


class LevelController:

    # MÉTODO PARA CREAR UN NIVEL
    @staticmethod
    @jwt_required()
    def create_level():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)

        if user['user_role'] != 'admin':
            return jsonify({"message": "Insufficient permissions."}), 403

        data = request.get_json()
        level_name = data.get('level_name')
        level_desc = data.get('level_desc')

        if not level_name or not level_desc:
            return jsonify({"error": "Por favor, llena todos los campos requeridos"}), 400

        response = Level.create_level(level_name, level_desc)

        if response == 'True':
            return jsonify({"message": "Nivel creado correctamente"}), 201
        else:
            return jsonify({"error": "No se pudo crear el nivel", "details": response}), 400

    # MÉTODO PARA EDITAR UN NIVEL
    @staticmethod
    @jwt_required()
    def update_level():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)

        if user['user_role'] != 'admin':
            return jsonify({"message": "Insufficient permissions."}), 403

        data = request.get_json()
        id_ = data.get('id')

        if not id_:
            return jsonify({"error": "El ID del nivel es requerido"}), 400

        field_mapping = {
            "name": "level_name",
            "description": "level_desc"
        }

        update_fields = {
            db_field: data[key]
            for key, db_field in field_mapping.items()
            if key in data
        }

        if not update_fields:
            return jsonify({"error": "No se recibieron campos para actualizar"}), 400

        response = Level.edit_level(id_, **update_fields)

        if response == 'True':
            return jsonify({"message": "Nivel actualizado correctamente"}), 200
        else:
            return jsonify({"error": "No se pudo actualizar el nivel", "details": response}), 400

    # MÉTODO PARA ELIMINAR UN NIVEL (borrado físico en este caso)
    @staticmethod
    @jwt_required()
    def delete_level():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)

        if user['user_role'] != 'admin':
            return jsonify({"message": "Insufficient permissions."}), 403

        data = request.get_json()
        id_ = data.get('id')

        if not id_:
            return jsonify({"error": "El ID del nivel es requerido"}), 400

        response = Level.delete_level(id_)

        if response == 'True':
            return jsonify({"message": "Nivel eliminado correctamente"}), 200
        else:
            return jsonify({"error": "No se pudo eliminar el nivel", "details": response}), 400

    # MÉTODO PARA OBTENER TODOS LOS NIVELES (sin paginación)
    @staticmethod
    @jwt_required()
    def get_all_levels():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)

        if user['user_role'] != 'admin':
            return jsonify({"message": "Insufficient permissions"}), 403

        try:
            levels = Level.get_all_levels()
            return jsonify({"levels": levels}), 200
        except Exception as e:
            return jsonify({"error": "No se pudieron obtener los niveles", "details": str(e)}), 500

    # MÉTODO PARA OBTENER NIVELES PAGINADOS Y FILTRADOS
    @staticmethod
    @jwt_required()
    def get_all_levels():
        try:
            # Validación de permisos
            current_user_id = get_jwt_identity()
            user = Usuario.get_user_by_id(current_user_id)

            if user['user_role'] != 'admin':
                return jsonify({"message": "Insufficient permissions"}), 403

            # Parámetros del body con valores por defecto
            data = request.get_json() or {}
            page = data.get('page', 1)
            per_page = data.get('per_page', 20)
            search = data.get('search', '')  # Búsqueda por nombre o descripción

            # Validación de paginación
            if page < 1 or per_page < 1:
                return jsonify({"error": "Pagination parameters must be ≥ 1"}), 400
            if per_page > 100:
                per_page = 100

            # Llamar al modelo para obtener los resultados paginados
            paginated_results = Level.get_paginated_levels(search=search, page=page, per_page=per_page)

            if isinstance(paginated_results, str):
                return jsonify({"error": "Database error", "details": paginated_results}), 500

            # Construcción de la respuesta
            response = {
                "levels": paginated_results['data'],
                "pagination": {
                    "total_items": paginated_results['total'],
                    "total_pages": paginated_results['pages'],
                    "current_page": page,
                    "items_per_page": per_page
                }
            }

            # Filtros aplicados
            if search:
                response["applied_filters"] = {"search": search}

            return jsonify(response), 200

        except Exception as e:
            return jsonify({"error": "Internal server error", "details": str(e)}), 500
                
    # MÉTODO PARA OBTENER NIVELES PAGINADOS Y FILTRADOS
    @staticmethod
    @jwt_required()
    def get_levels_paginated():
        try:
            current_user_id = get_jwt_identity()
            user = Usuario.get_user_by_id(current_user_id)

            if user['user_role'] != 'admin':
                return jsonify({"message": "Insufficient permissions"}), 403

            data = request.get_json() or {}
            page = data.get('page', 1)
            per_page = data.get('per_page', 20)
            search = data.get('search', '')  # Búsqueda por nombre o descripción

            if page < 1 or per_page < 1:
                return jsonify({"error": "Pagination parameters must be ≥ 1"}), 400
            if per_page > 100:
                per_page = 100

            paginated_results = Level.get_paginated_levels(search=search, page=page, per_page=per_page)

            if isinstance(paginated_results, str):
                return jsonify({"error": "Database error", "details": paginated_results}), 500

            response = {
                "levels": paginated_results['data'],
                "pagination": {
                    "total_items": paginated_results['total'],
                    "total_pages": paginated_results['pages'],
                    "current_page": page,
                    "items_per_page": per_page
                }
            }

            if search:
                response["applied_filters"] = {"search": search}

            return jsonify(response), 200

        except Exception as e:
            return jsonify({"error": "Internal server error", "details": str(e)}), 500

