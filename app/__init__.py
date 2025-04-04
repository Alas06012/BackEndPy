from flask import Flask
from flask_mysqldb import MySQL
from flask_jwt_extended import JWTManager
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from config import Config
from flask_cors import CORS

# Inicializar extensiones
mysql = MySQL()
jwt = JWTManager()

def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)

    # Inicializar extensiones
    mysql.init_app(app)
    jwt.init_app(app)
    
    # limiter = Limiter(
    #     key_func=get_remote_address,  # Usa la IP del usuario para limitar intentos
    #     app=app,
    #     default_limits=["5 per minute"]  # 5 intentos por minuto 
    # )
    
    #CORS(app, resources={r"/register": {"origins": "http://localhost:5173"}})
    CORS(app)
    
    
    # Importar rutas
    from app.routes.usuario_routes import usuario_routes
    app.register_blueprint(usuario_routes)

    return app
