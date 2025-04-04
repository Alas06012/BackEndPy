from flask_jwt_extended import JWTManager
from flask import jsonify, request
from app import app

# Inicializar JWT
jwt = JWTManager(app)

# Opcional: función para configurar claves JWT
@jwt.expired_token_loader
def my_expired_token_callback(jwt_header, jwt_payload):
    return jsonify({"message": "Token has expired"}), 401

@jwt.invalid_token_loader
def my_invalid_token_callback(error):
    return jsonify({"message": "Invalid token"}), 422


@jwt.unauthorized_loader
def missing_token_callback(error):
    return jsonify({"error": "Token not sent"}), 401