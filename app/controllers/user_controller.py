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
            return jsonify({"message": "Por favor, llena toda la información requerida"}), 400

        # Hashear la contraseña antes de guardarla
        hashed_password = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt())
        
        # Crear el usuario en la base de datos
        response = Usuario.create_user(name, lastname, carnet, email, role, hashed_password.decode('utf-8'))
        
        if response == 'True':
            return jsonify({"message": "Usuario Creado Correctamente"}), 201
        elif 'duplicate entry' in str(response).lower(): 
            return jsonify({"error": "El correo electrónico ya está registrado"}), 400
        else:
            return jsonify({"error": "El usuario no pudo ser registrado, hubo un error"}), 400
        

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
            return jsonify({"message": "El usuario no tiene permisos para crear otros usuarios"}), 404
        
        data = request.get_json()
        name = data.get('name')
        lastname = data.get('lastname')
        carnet = data.get('carnet')
        email = data.get('email')
        role = 'student'
        password = data.get('password')
        
        
        if not email or not password or not name or not lastname or not carnet:
            return jsonify({"message": "Por favor, llena toda la información requerida"}), 400

        # Hashear la contraseña antes de guardarla
        hashed_password = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt())
        
        # Crear el usuario en la base de datos
        response = Usuario.create_user(name, lastname, carnet, email, role, hashed_password.decode('utf-8'))
        
        if response == 'True':
            return jsonify({"message": "Usuario Creado Correctamente"}), 201
        elif 'duplicate entry' in str(response).lower(): 
            return jsonify({"error": "El correo electrónico ya está registrado"}), 400
        else:
            return jsonify({"error": "El usuario no pudo ser registrado, hubo un error"}), 400
        
        
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
            return jsonify({"message": "El usuario no tiene permisos para eliminar otros usuarios"}), 404
        
        data = request.get_json()
        email = data.get('email')
        
        if not email:
            return jsonify({"message": "Por favor, llena toda la información requerida"}), 400

        # Crear el usuario en la base de datos
        response = Usuario.delete_user(email)
        
        if response == 'True':
            return jsonify({"message": "Usuario Desactivado Correctamente"}), 201
        elif 'duplicate entry' in str(response).lower(): 
            return jsonify({"error": "El correo electrónico ya está registrado"}), 400
        else:
            return jsonify({"error": "El usuario no pudo ser eliminado, hubo un error"}), 400
        
        
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
            return jsonify({"message": "El usuario no tiene permisos para activar otros usuarios"}), 404
        
        data = request.get_json()
        email = data.get('email')
        
        if not email:
            return jsonify({"message": "Por favor, llena toda la información requerida"}), 400

        # Crear el usuario en la base de datos
        response = Usuario.activate_user(email)
        print(response)
        
        if response == 'True':
            return jsonify({"message": "Usuario Activado Correctamente"}), 201
        elif 'duplicate entry' in str(response).lower(): 
            return jsonify({"error": "El correo electrónico ya está registrado"}), 400
        else:
            return jsonify({"error": "El usuario no pudo ser activado, hubo un error"}), 400
        
        
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
            return jsonify({"message": "El usuario no tiene permisos para modificar otros usuarios"}), 404
        
        data = request.get_json()
        name = data.get('name')
        lastname = data.get('lastname')
        carnet = data.get('carnet')
        current_email = data.get('current_email')
        new_email = data.get('new_email')
        role = data.get('role')
        
        if not current_email or not name or not lastname or not carnet or not role:
            return jsonify({"message": "Por favor, llena toda la información requerida"}), 400
        elif not new_email :
            # Editar el usuario en la base de datos
            response = Usuario.edit_user(name, lastname, carnet, role, current_email)
        else:
             # Editar el usuario en la base de datos
            response = Usuario.edit_user(name, lastname, carnet, role, current_email, new_email)
               
        if response == 'True':
            return jsonify({"message": "Usuario Modificado Correctamente"}), 201
        elif 'duplicate entry' in str(response).lower(): 
            return jsonify({"error": "El correo electrónico ya está registrado"}), 400
        else:
            return jsonify({"error": "El usuario no pudo ser modificado, hubo un error"}), 400
        

    #METODO MOSTRAR TODOS LOS USUARIOS ACTIVOS
    #--------------------
    # UNICAMENTE VALIDO PARA USUARIOS ADMIN
    #
    @staticmethod
    @jwt_required()
    def get_active_users():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)
        
        if user['user_role'] != 'admin':
            return jsonify({"message": "El usuario no tiene permisos para modificar otros usuarios"}), 404
        
        users = Usuario.get_active_users()
        
        # Si es un error en texto, retornamos como error
        if isinstance(users, str):
            return jsonify({"error": "No se pudieron obtener los usuarios", "detalle": users}), 500
        
        # Devolver usuarios en formato JSON
        return jsonify({"usuarios_activos": users}), 200
    
    
     #METODO MOSTRAR TODOS LOS USUARIOS INACTIVOS
    #--------------------
    # UNICAMENTE VALIDO PARA USUARIOS ADMIN
    #
    @staticmethod
    @jwt_required()
    def get_inactive_users():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)
        
        if user['user_role'] != 'admin':
            return jsonify({"message": "El usuario no tiene permisos para modificar otros usuarios"}), 404
        
        users = Usuario.get_inactive_users()
        
        # Si es un error en texto, retornamos como error
        if isinstance(users, str):
            return jsonify({"error": "No se pudieron obtener los usuarios", "detalle": users}), 500
        
        # Devolver usuarios en formato JSON
        return jsonify({"usuarios_inactivos": users}), 200
       
       


