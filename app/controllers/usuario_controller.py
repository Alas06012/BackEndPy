from app.models.usuario_model import Usuario
from flask import jsonify, request
from flask_jwt_extended import create_access_token, jwt_required, get_jwt_identity
import bcrypt

class UsuarioController:

    @staticmethod
    def register_user():
        data = request.get_json()
        name = data.get('name')
        email = data.get('email')
        password = data.get('password')

        if not email or not password or not name:
            return jsonify({"message": "Email, password and name are required"}), 400

        # Hashear la contraseña antes de guardarla
        hashed_password = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt())
        
        # Crear el usuario en la base de datos
        response = Usuario.create_user(name, email, hashed_password.decode('utf-8'))
        
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

        # Obtener el usuario de la base de datos
        user = Usuario.get_user_by_email(email)

        if user and bcrypt.checkpw(password.encode('utf-8'), user['password'].encode('utf-8')):
            access_token = create_access_token(identity=user['id'])
            return jsonify(access_token=access_token), 200

        return jsonify({"message": "Invalid email or password"}), 401



    @staticmethod
    @jwt_required()
    def get_user_info():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)

        if user:
            return jsonify({"id": user['id'], "email": user['email']}), 200
        return jsonify({"message": "User not found"}), 404
