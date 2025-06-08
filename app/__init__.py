import os
from flask import Flask
from flask_mysqldb import MySQL
from flask_jwt_extended import JWTManager
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from flask_mail import Mail
from config import Config
from flask_cors import CORS
# Inicializar extensiones
mysql = MySQL()
jwt = JWTManager()
mail = Mail()

def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)

    # Inicializar extensiones
    mysql.init_app(app)
    jwt.init_app(app)
    mail.init_app(app)
    
    CORS(app, resources={
        r"/*": {
            "origins": os.environ.get('ALLOWED_ORIGINS').split(',')
        }
    })
    
    # Importar rutas
    from app.routes.usuario_routes import usuario_routes
    app.register_blueprint(usuario_routes)
    
    return app
