from app.models.usuario_model import Usuario
from flask import jsonify, request
from flask_jwt_extended import create_access_token, jwt_required, get_jwt_identity
from flask_jwt_extended import jwt_required, get_jwt_identity, create_access_token
import bcrypt

class UsuarioController:

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

        if user and bcrypt.checkpw(password.encode('utf-8'), user['password'].encode('utf-8')):
            access_token = create_access_token(identity=user['id'])
            refresh_token = create_access_token(identity=user['id'], fresh=False)
            return jsonify({
                "access_token": access_token,
                "refresh_token": refresh_token,
                "user": {
                    "id": user['id'],  
                    "name": user['name'],  
                    "lastname": user['lastname'], 
                    "email": user['email'],
                    "role": user['role']
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
                    "id": user['id'],  
                    "name": user['name'],  
                    "lastname": user['lastname'], 
                    "email": user['email'],
                    "role": user['role']
                }), 200
        return jsonify({"message": "User not found"}), 404
    
    
    @staticmethod
    @jwt_required(refresh=True)
    def refresh_token():
        current_user_id = get_jwt_identity()
        new_token = create_access_token(identity=current_user_id)
        return jsonify(access_token=new_token), 200
