from app.models.user_model import Usuario
from app.models.prompt_model import Prompt
from flask import jsonify, request
from flask_jwt_extended import create_access_token, jwt_required, get_jwt_identity
from flask_jwt_extended import jwt_required, get_jwt_identity, create_access_token
import bcrypt

class PromptController:

    @staticmethod
    @jwt_required()
    def create_prompt():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)
        
        if user['user_role'] != 'admin':
            return jsonify({"message": "El usuario no tiene permisos necesarios."}), 404
        
        data = request.get_json()
        prompt_name = data.get('prompt_name')
        prompt_value = data.get('prompt_value')

        if not prompt_name or not prompt_value:
            return jsonify({"message": "Por favor, llena toda la información requerida"}), 400

        response = Prompt.create_prompt(prompt_name, prompt_value)
        
        if response == 'True':
            return jsonify({"message": "Prompt Creado Correctamente"}), 201
        else:
            return jsonify({"error": "El prompt no pudo ser registrado, hubo un error"}), 400
        
        
   
    @staticmethod
    @jwt_required()
    def edit_prompt():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)
        
        if user['user_role'] != 'admin':
            return jsonify({"message": "El usuario no tiene permisos necesarios."}), 404
        
        data = request.get_json()
        prompt_name = data.get('prompt_name')
        prompt_value = data.get('prompt_value')
        
        if not prompt_name or not prompt_value :
            return jsonify({"message": "Por favor, llena toda la información requerida"}), 400
        else:
             # EN LUGAR DE EDITAR SE CREA UNO NUEVO Y SE INVALIDA EL ANTERIOR
            response = Prompt.create_prompt(prompt_name, prompt_value)
               
        if response == 'True':
            return jsonify({"message": "Prompt Creado Correctamente"}), 201
        else:
            return jsonify({"error": "El prompt no pudo ser registrado, hubo un error"}), 400
        
        
    @staticmethod
    @jwt_required()
    def activate_prompt():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)
        
        if user['user_role'] != 'admin':
            return jsonify({"message": "El usuario no tiene permisos necesarios."}), 404
        
        data = request.get_json()
        id_ = data.get('id_')
        
        if not id_ :
            return jsonify({"message": "Por favor, llena toda la información requerida"}), 400
        else:
             # SE DESACTIVAN LOS DEMAS Y SE ACTIVA EL REQUERIDO
            response = Prompt.activate_prompt(id_)
               
        if response == 'True':
            return jsonify({"message": "Prompt Activado Correctamente"}), 201
        else:
            return jsonify({"error": "El prompt no pudo ser activado, hubo un error"}), 400
        

    @staticmethod
    @jwt_required()
    def get_filtered_prompts():
        try:
            current_user_id = get_jwt_identity()
            user = Usuario.get_user_by_id(current_user_id)

            if user['user_role'] != 'admin':
                return jsonify({"message": "Acceso denegado: Se requieren privilegios de administrador"}), 403

            data = request.get_json() or {}
            page = data.get('page', 1)
            per_page = data.get('per_page', 20)

            filters = {
                "prompt_name": data.get("prompt_name"),
                "prompt_value": data.get("prompt_value"),
                "status": data.get("status")
            }

            paginated_results = Prompt.get_paginated_prompts(
                filters=filters,
                page=page,
                per_page=per_page
            )

            if isinstance(paginated_results, str):
                return jsonify({"error": "Error en la base de datos", "details": paginated_results}), 500

            response = {
                "prompts": paginated_results['data'],
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
       
       


