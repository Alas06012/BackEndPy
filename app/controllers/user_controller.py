from app.models.user_model import Usuario
from flask import jsonify, request
from flask_jwt_extended import create_access_token, jwt_required, get_jwt_identity
from flask_jwt_extended import jwt_required, get_jwt_identity, create_access_token
import bcrypt

class UserController:

    @staticmethod
    def register_user():
        data = request.get_json()
        name = data.get('name')
        lastname = data.get('lastname')
        carnet = data.get('carnet')
        email = data.get('email')
        role = 'student'
        password = data.get('password')

        if not email or not password or not name or not lastname or not carnet:
            return jsonify({"message": "Please complete all required fields"}), 400

        # Hashear la contraseña antes de guardarla
        hashed_password = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt())
        
        # Crear el usuario en la base de datos
        response = Usuario.create_user(name, lastname, carnet, email, role, hashed_password.decode('utf-8'))
        
        if response == 'True':
            return jsonify({"message": "The user was successfully created"}), 201
        elif 'duplicate entry' in str(response).lower(): 
            return jsonify({"error": "The email or student ID is already registered"}), 400
        else:
            return jsonify({"error": "Registration failed due to an error"}), 400
        

    @staticmethod
    def login_user():
        data = request.get_json()
        email = data.get('email')
        password = data.get('password')

        if not email or not password:
            return jsonify({"message": "Email and password are required"}), 400

        user = Usuario.get_user_by_email(email)

        if user and bcrypt.checkpw(password.encode('utf-8'), user['user_password'].encode('utf-8')):
            access_token = create_access_token(identity=str(user['pk_user']))
            refresh_token = create_access_token(identity=str(user['pk_user']), fresh=False)
            return jsonify({
                "access_token": access_token,
                "refresh_token": refresh_token,
                "user": {
                    "id": user['pk_user'],  
                    "name": user['user_name'],  
                    "lastname": user['user_lastname'], 
                    "email": user['user_email'],
                    "role": user['user_role']
                }
            }), 200

        return jsonify({"message": "Invalid email or password"}), 401



    @staticmethod
    @jwt_required()
    def get_user_info():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)

        if user:
            return jsonify(
                {
                    "id": user['pk_user'],  
                    "name": user['user_name'],  
                    "lastname": user['user_lastname'], 
                    "email": user['user_email'],
                    "role": user['user_role']
                }), 200
        return jsonify({"message": "User not found"}), 404
    
    
    @staticmethod
    @jwt_required(refresh=True)
    def refresh_token():
        current_user_id = get_jwt_identity()
        new_token = create_access_token(identity=current_user_id)
        return jsonify(access_token=new_token), 200
    
    
    
    
    #METODO CREAR USUARIO
    #--------------------
    # UNICAMENTE VALIDO PARA USUARIOS ADMIN
    #
    @staticmethod
    @jwt_required()
    def create_user():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)
        
        if user['user_role'] != 'admin':
            return jsonify({"message": "The user is not authorized to create other users"}), 404
        
        data = request.get_json()
        name = data.get('name')
        lastname = data.get('lastname')
        carnet = data.get('carnet')
        email = data.get('email')
        role = 'student'
        password = data.get('password')
        
        
        if not email or not password or not name or not lastname or not carnet:
            return jsonify({"message": "Please complete all required fields"}), 400

        # Hashear la contraseña antes de guardarla
        hashed_password = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt())
        
        # Crear el usuario en la base de datos
        response = Usuario.create_user(name, lastname, carnet, email, role, hashed_password.decode('utf-8'))
        
        if response == 'True':
            return jsonify({"message": "The user was successfully created"}), 201
        elif 'duplicate entry' in str(response).lower(): 
            return jsonify({"error": "The email or student ID is already registered"}), 400
        else:
            return jsonify({"error": "Registration failed due to an error"}), 400
        
        
    #METODO ELIMINAR USUARIO
    #--------------------
    # UNICAMENTE VALIDO PARA USUARIOS ADMIN
    #
    @staticmethod
    @jwt_required()
    def delete_user():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)
        
        if user['user_role'] != 'admin':
            return jsonify({"message": "The user is not authorized to delete other users"}), 404
        
        data = request.get_json()
        email = data.get('email')
        
        if not email:
            return jsonify({"message": "Please complete all required fields"}), 400

        # Crear el usuario en la base de datos
        response = Usuario.delete_user(email)
        
        if response == 'True':
            return jsonify({"message": "User successfully deactivated"}), 201
        elif 'duplicate entry' in str(response).lower(): 
            return jsonify({"error": "The email or student ID is already registered."}), 400
        else:
            return jsonify({"error": "Failed to delete the user. An error occurred"}), 400
        
        
     #METODO ACTIVAR USUARIO
    #--------------------
    # UNICAMENTE VALIDO PARA USUARIOS ADMIN
    #
    @staticmethod
    @jwt_required()
    def activate_user():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)
        
        if user['user_role'] != 'admin':
            return jsonify({"message": "The user is not authorized to activate other users."}), 404
        
        data = request.get_json()
        email = data.get('email')
        
        if not email:
            return jsonify({"message": "Please complete all required fields"}), 400

        # Crear el usuario en la base de datos
        response = Usuario.activate_user(email)
        print(response)
        
        if response == 'True':
            return jsonify({"message": "The user was successfully activated"}), 201
        elif 'duplicate entry' in str(response).lower(): 
            return jsonify({"error": "The email or student ID is already registered"}), 400
        else:
            return jsonify({"error": "Activation failed due to an error"}), 400
        
        
    #METODO EDITAR USUARIO
    #--------------------
    # UNICAMENTE VALIDO PARA USUARIOS ADMIN
    #
    @staticmethod
    @jwt_required()
    def edit_user():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)
        
        if user['user_role'] != 'admin':
            return jsonify({"message": "The user is not authorized to edit other users"}), 404
        
        data = request.get_json()
        name = data.get('name')
        lastname = data.get('lastname')
        carnet = data.get('carnet')
        current_email = data.get('current_email')
        new_email = data.get('new_email')
        role = data.get('role')
        
        if not current_email or not name or not lastname or not carnet or not role:
            return jsonify({"message": "Please complete all required fields"}), 400
        elif not new_email :
            # Editar el usuario en la base de datos
            response = Usuario.edit_user(name, lastname, carnet, role, current_email)
        else:
             # Editar el usuario en la base de datos
            response = Usuario.edit_user(name, lastname, carnet, role, current_email, new_email)
               
        if response == 'True':
            return jsonify({"message": "The user was successfully modified"}), 201
        elif 'duplicate entry' in str(response).lower(): 
            return jsonify({"error": "The email or student ID is already registered"}), 400
        else:
            return jsonify({"error": "Action modify failed due to an error"}), 400
        

    @staticmethod
    @jwt_required()
    def get_filtered_users():
        try:
            current_user_id = get_jwt_identity()
            user = Usuario.get_user_by_id(current_user_id)

            if user['user_role'] != 'admin':
                return jsonify({"message": "The user is not authorized to fetch users data"}), 403

            data = request.get_json() or {}
            page = data.get('page', 1)
            per_page = data.get('per_page', 20)

            filters = {
                "user_email": data.get("user_email"),
                "user_name": data.get("user_name"),
                "user_lastname": data.get("user_lastname"),
                "user_carnet": data.get("user_carnet"),
                "user_role": data.get("user_role"),
                "status": data.get("status")
            }

            paginated_results = Usuario.get_paginated_users(
                filters=filters,
                page=page,
                per_page=per_page
            )

            if isinstance(paginated_results, str):
                return jsonify({"error": "Error in database", "details": paginated_results}), 500

            response = {
                "users": paginated_results['data'],
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
            return jsonify({"error": "Exception", "details": str(e)}), 500
       
       


