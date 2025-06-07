from app.models.Section_model import SectionModel as Section
from app.models.user_model import Usuario
from flask import jsonify, request
from flask_jwt_extended import jwt_required, get_jwt_identity


class SectionController:

    @staticmethod
    @jwt_required()
    def create_section():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)

        if user['user_role'] != 'admin':
            return jsonify({"message": "Insufficient permissions."}), 403

        data = request.get_json()
        section_type = data.get('type_')
        section_desc = data.get('section_desc')

        if not section_type or not section_desc:
            return jsonify({"error": "Por favor, llena todos los campos requeridos"}), 400

        response = Section.create_section(section_type, section_desc)

        if response == 'True':
            return jsonify({"message": "Sección creada correctamente"}), 201
        else:
            return jsonify({"error": "No se pudo crear la sección", "details": response}), 400

    @staticmethod
    @jwt_required()
    def update_section():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)

        if user['user_role'] != 'admin':
            return jsonify({"message": "Insufficient permissions."}), 403

        data = request.get_json()
        section_pk = data.get('id')

        if not section_pk:
            return jsonify({"error": "El ID de la sección es requerido"}), 400

        field_mapping = {
            "type": "type_",
            "description": "section_desc"
        }

        update_fields = {
            db_field: data[key]
            for key, db_field in field_mapping.items()
            if key in data
        }

        if not update_fields:
            return jsonify({"error": "No se recibieron campos para actualizar"}), 400

        response = Section.edit_section(section_pk, **update_fields)

        if response == 'True':
            return jsonify({"message": "Sección actualizada correctamente"}), 200
        else:
            return jsonify({"error": "No se pudo actualizar la sección", "details": response}), 400

    @staticmethod
    @jwt_required()
    def delete_section():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)

        if user['user_role'] != 'admin':
            return jsonify({"message": "Insufficient permissions."}), 403

        data = request.get_json()
        section_pk = data.get('id')

        if not section_pk:
            return jsonify({"error": "El ID de la sección es requerido"}), 400

        response = Section.delete_section(section_pk)

        if response == 'True':
            return jsonify({"message": "Sección eliminada correctamente"}), 200
        else:
            return jsonify({"error": "No se pudo eliminar la sección", "details": response}), 400

  # MÉTODO PARA OBTENER TODAS LAS SECCTIONS (sin paginación)
    @staticmethod
    @jwt_required()
    def get_all_sections():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)

        if user['user_role'] not in ['admin', 'teacher']:
            return jsonify({"message": "Insufficient permissions"}), 403

        try:
            sections = Section.get_all_sections()
            return jsonify({"sections": sections}), 200
        except Exception as e:
            return jsonify({"error": "No se pudieron obtener las secciones", "details": str(e)}), 500


    @staticmethod
    @jwt_required()
    def get_all_sections():
        try:
            # Validación de permisos
            current_user_id = get_jwt_identity()
            user = Usuario.get_user_by_id(current_user_id)

            if user['user_role'] not in ['admin', 'teacher']:
                return jsonify({"message": "Insufficient permissions"}), 403

            # Parámetros del body con valores por defecto
            data = request.get_json() or {}
            page = data.get('page', 1)
            per_page = data.get('per_page', 20)
            search = data.get('search', '')  # Búsqueda por tipo o descripción

            # Validación de paginación
            if page < 1 or per_page < 1:
                return jsonify({"error": "Pagination parameters must be ≥ 1"}), 400
            if per_page > 100:
                per_page = 100

            # Llamar al modelo para obtener los resultados paginados
            paginated_results = Section.get_paginated_sections(search=search, page=page, per_page=per_page)

            if isinstance(paginated_results, str):
                return jsonify({"error": "Database error", "details": paginated_results}), 500

            # Construcción de la respuesta
            response = {
                "sections": paginated_results['data'],
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
        
        
    @staticmethod
    @jwt_required()
    def get_sections_paginated():
        try:
            current_user_id = get_jwt_identity()
            user = Usuario.get_user_by_id(current_user_id)

            if user['user_role'] not in ['admin', 'teacher']:
                return jsonify({"message": "Insufficient permissions"}), 403

            data = request.get_json() or {}
            page = data.get('page', 1)
            per_page = data.get('per_page', 20)
            search = data.get('search', '')

            if page < 1 or per_page < 1:
                return jsonify({"error": "Pagination parameters must be ≥ 1"}), 400
            if per_page > 100:
                per_page = 100

            paginated_results = Section.get_paginated_sections(search=search, page=page, per_page=per_page)

            if isinstance(paginated_results, str):
                return jsonify({"error": "Database error", "details": paginated_results}), 500

            response = {
                "sections": paginated_results['data'],
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
