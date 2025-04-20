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
        
        if user['user_role'] != 'admin':
            return jsonify({"message": "El usuario no tiene permisos necesarios."}), 404
        
        data = request.get_json()
        title = data.get('title')
        content = data.get('content')
        type_ = data.get('type')
        url = data.get('url')
        
        if not content or not title or not type_:
            return jsonify({"message": "Por favor, llena toda la información requerida"}), 400

        if type_ != 'LISTENING' and type_ != 'READING':
            return jsonify({"message": "Por favor, define si el tipo es LISTENING o READING"}), 400

        response = QuestionTitle.create_title(title, content, type_, url)
        
        if response == 'True':
            return jsonify({"message": "Encabezado Creado Correctamente"}), 201
        else:
            return jsonify({"error": "El encabezado no pudo ser registrado, hubo un error"}), 400
        
       
    #METODO MOSTRAR TODOS LOS TITLES ACTIVOS
    #--------------------
    # UNICAMENTE VALIDO PARA USUARIOS ADMIN
    #
    @staticmethod
    @jwt_required()
    def get_active_titles():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)
        
        if user['user_role'] != 'admin':
            return jsonify({"message": "El usuario no tiene permisos necesarios."}), 404
        
        titles = QuestionTitle.get_active_titles()
        
        # Si es un error en texto, retornamos como error
        if isinstance(titles, str):
            return jsonify({"error": "No se pudieron obtener los titles", "detalle": titles}), 500
        
        # Devolver usuarios en formato JSON
        return jsonify({"titles_activos": titles}), 200
    
    
    
    #METODO MOSTRAR TODOS LOS TITLES INACTIVOS
    #--------------------
    # UNICAMENTE VALIDO PARA USUARIOS ADMIN
    #
    @staticmethod
    @jwt_required()
    def get_inactive_titles():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)
        
        if user['user_role'] != 'admin':
            return jsonify({"message": "El usuario no tiene permisos necesarios."}), 404
        
        titles = QuestionTitle.get_inactive_titles()
        
        # Si es un error en texto, retornamos como error
        if isinstance(titles, str):
            return jsonify({"error": "No se pudieron obtener los titles", "detalle": titles}), 500
        
        # Devolver usuarios en formato JSON
        return jsonify({"titles_inactivos": titles}), 200
    
    
    
    
    #METODO EDITAR TITLES 
    #--------------------
    # UNICAMENTE VALIDO PARA USUARIOS ADMIN
    #
    @staticmethod
    @jwt_required()
    def edit_title():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)
        
        if user['user_role'] != 'admin':
            return jsonify({"message": "El usuario no tiene permisos necesarios."}), 403

        data = request.get_json()
        id_ = data.get('id')
        type_ = data.get('type')
        url = data.get('url')
        status = data.get('status')
        
        if not id_:
            return jsonify({"error": "El ID del título es requerido"}), 400

        if type_ and type_ not in ['LISTENING', 'READING']:
            return jsonify({"message": "Por favor, define si el tipo es LISTENING o READING"}), 400
        else:
            if not url and type_ == 'LISTENING':
                return jsonify({"error": "Por favor, agrega la url del audio dentro del json"}), 400

        # Mapeo del JSON recibido a los nombres de columnas reales
        field_mapping = {
            "title": "title_name",
            "content": "title_test",
            "type": "title_type",
            "url": "title_url",
            "status": "status"
        }

        # Construir diccionario solo con campos presentes en el JSON
        update_fields = {
            db_field: data[key]
            for key, db_field in field_mapping.items()
            if key in data
        }

        response = QuestionTitle.edit_title(id_, **update_fields)
        
        #Si el estado del titulo es INACTIVE se desactivaran tambien las preguntas asociadas al title
        if status == 'INACTIVE':
            QuestionTitle.inactivate_questions_per_title(title_id=id_)
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
    def inactivate_title(): 
        try:
            current_user_id = get_jwt_identity()
            user = Usuario.get_user_by_id(current_user_id)

            # Verificación de permisos
            if not user or user.get('user_role') != 'admin':
                return jsonify({"message": "El usuario no tiene permisos necesarios."}), 403

            # Obtener ID desde el body
            data = request.get_json()
            id_ = data.get('id')

            if not id_:
                return jsonify({"error": "El ID del título es requerido."}), 400

            # Inactivar título y preguntas relacionadas
            success_title = QuestionTitle.delete_title(id_)
            success_questions = QuestionTitle.inactivate_questions_per_title(title_id=id_)

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
        
        

    
    
