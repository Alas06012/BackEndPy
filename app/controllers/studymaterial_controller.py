from app.models.studymaterial_model import StudyMaterial
from flask import jsonify, request
from flask_jwt_extended import jwt_required, get_jwt_identity
from app.models.user_model import Usuario
from gcs_utils import upload_file_to_gcs
from werkzeug.utils import secure_filename

class StudyMaterialController:

    @staticmethod
    @jwt_required()
    def create_material():
        try:
            current_user_id = get_jwt_identity()
            user = Usuario.get_user_by_id(current_user_id)

            if user['user_role'] != 'admin':
                return jsonify({"error": "Acceso denegado: Se requieren privilegios de administrador"}), 403

            # Obtener datos del formulario
            title = request.form.get('studymaterial_title')
            description = request.form.get('studymaterial_desc')
            material_type = request.form.get('studymaterial_type')
            level_fk = request.form.get('level_fk')
            tags = request.form.get('studymaterial_tags')
            
            # Validar campos obligatorios
            if not all([title, level_fk]):
                return jsonify({"error": "Título y nivel son campos requeridos"}), 400

            # Manejar la subida del archivo
            if 'file' not in request.files:
                return jsonify({"error": "No se ha proporcionado ningún archivo"}), 400
                
            file = request.files['file']
            if file.filename == '':
                return jsonify({"error": "Nombre de archivo vacío"}), 400

            # Validar tipo de archivo (ejemplo básico)
            allowed_extensions = {'pdf', 'doc', 'docx', 'ppt', 'pptx', 'mp4', 'mov'}
            if '.' in file.filename:
                file_ext = file.filename.rsplit('.', 1)[1].lower()
                if file_ext not in allowed_extensions:
                    return jsonify({"error": "Tipo de archivo no permitido"}), 400

            # Subir a GCS
            try:
                file_url = upload_file_to_gcs(file)
            except Exception as e:
                return jsonify({"error": "Error subiendo archivo", "details": str(e)}), 500

            # Crear material de estudio
            response = StudyMaterial.create_study_material(
                title=title,
                description=description,
                material_type=material_type,
                url=file_url,  # Usar la URL de GCS
                level_fk=level_fk,
                tags=tags
            )

            if response == 'True':
                return jsonify({
                    "message": "Material creado exitosamente",
                    "file_url": file_url
                }), 201
            else:
                return jsonify({"error": "Error al crear material", "details": response}), 500

        except Exception as e:
            return jsonify({"error": "Error interno del servidor", "details": str(e)}), 500

    @staticmethod
    @jwt_required()
    def get_all_materials():
        try:
            materials = StudyMaterial.get_all_study_materials()
            return jsonify(materials), 200
        except Exception as e:
            return jsonify({"error": "Error al obtener materiales", "details": str(e)}), 500

    @staticmethod
    @jwt_required()
    def get_material():
        try:
            data = request.get_json()
            material_id = data.get('pk_studymaterial')

            if not material_id:
                return jsonify({"error": "Se requiere el ID del material"}), 400

            material = StudyMaterial.get_study_material_by_id(material_id)
            
            if not material:
                return jsonify({"error": "Material no encontrado"}), 404
                
            return jsonify(material), 200
        except Exception as e:
            return jsonify({"error": "Error al obtener material", "details": str(e)}), 500

    @staticmethod
    @jwt_required()
    def update_material():
        try:
            current_user_id = get_jwt_identity()
            user = Usuario.get_user_by_id(current_user_id)

            if user['user_role'] != 'admin':
                return jsonify({"error": "Acceso denegado: Se requieren privilegios de administrador"}), 403

            data = request.get_json()
            material_id = data.get('pk_studymaterial')
            title = data.get('studymaterial_title')
            description = data.get('studymaterial_desc')
            material_type = data.get('studymaterial_type')
            url = data.get('studymaterial_url')
            level_fk = data.get('level_fk')
            tags = data.get('studymaterial_tags')

            if not material_id:
                return jsonify({"error": "Se requiere el ID del material"}), 400

            response = StudyMaterial.update_study_material(
                material_id,
                title,
                description,
                material_type,
                url,
                level_fk,
                tags
            )

            if response == 'True':
                return jsonify({"message": "Material actualizado exitosamente"}), 200
            else:
                return jsonify({"error": "Error al actualizar material", "details": response}), 500

        except Exception as e:
            return jsonify({"error": "Error interno del servidor", "details": str(e)}), 500

    @staticmethod
    @jwt_required()
    def delete_material():
        try:
            current_user_id = get_jwt_identity()
            user = Usuario.get_user_by_id(current_user_id)

            if user['user_role'] != 'admin':
                return jsonify({"error": "Acceso denegado: Se requieren privilegios de administrador"}), 403

            data = request.get_json()
            material_id = data.get('pk_studymaterial')

            if not material_id:
                return jsonify({"error": "Se requiere el ID del material"}), 400

            response = StudyMaterial.delete_study_material(material_id)

            if response == 'True':
                return jsonify({"message": "Material eliminado exitosamente"}), 200
            else:
                return jsonify({"error": "Error al eliminar material", "details": response}), 500

        except Exception as e:
            return jsonify({"error": "Error interno del servidor", "details": str(e)}), 500

    @staticmethod
    @jwt_required()
    def get_filtered_materials():
        try:
            current_user_id = get_jwt_identity()
            user = Usuario.get_user_by_id(current_user_id)

            if user['user_role'] != 'admin':
                return jsonify({"error": "Acceso denegado: Se requieren privilegios de administrador"}), 403

            data = request.get_json() or {}
            page = data.get('page', 1)
            per_page = data.get('per_page', 20)

            filters = {
                "studymaterial_title": data.get("studymaterial_title"),
                "studymaterial_desc": data.get("studymaterial_desc"),
                "studymaterial_type": data.get("studymaterial_type"),
                "level_fk": data.get("level_fk"),
                "studymaterial_tags": data.get("studymaterial_tags")
            }

            paginated_results = StudyMaterial.get_paginated_study_materials(
                filters=filters,
                page=page,
                per_page=per_page
            )

            if isinstance(paginated_results, str):
                return jsonify({"error": "Error en la base de datos", "details": paginated_results}), 500

            response = {
                "materials": paginated_results['data'],
                "pagination": {
                    "total_items": paginated_results['total'],
                    "total_pages": paginated_results['pages'],
                    "current_page": page,
                    "items_per_page": per_page
                },
                "applied_filters": {k: v for k, v in filters.items() if v}
            }

            return jsonify(response), 200

        except Exception as e:
            return jsonify({"error": "Error interno", "details": str(e)}), 500