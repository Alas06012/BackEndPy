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
    
    # limiter_ = Limiter(
    #     key_func=get_remote_address,  # Usa la IP del usuario para limitar intentos
    #     default_limits=["15 per minute"]  # 15 intentos por minuto 
    # )
    # limiter_.init_app(app)
    
    #CORS(app, resources={r"/register": {"origins": "http://localhost:5173"}})
    #CORS(app)
    CORS(app, resources={r"/*": {"origins": ["http://localhost:5173", "http://host.docker.internal:5173", "http://host.docker.internal:5173/auth"]}})
    
    
    # Importar rutas
    from app.routes.user_routes import user_routes
    from app.routes.title_routes import title_routes
    from app.routes.question_routes import question_routes
    from app.routes.answer_routes import answer_routes
    from app.routes.prompt_route import prompt_routes
    from app.routes.studymaterial_routes import studymaterial_routes
    from app.routes.test_route import test_routes
    from app.routes.test_comments_routes import test_comments_routes
    from app.routes.test_detail_routes import test_detail_routes
    from app.routes.student_dashboard_routes import student_dashboard_routes
    from app.routes.admin_dashboard_routes import admin_dashboard_routes
    from app.routes.ai_routes import questions_ai_routes
    from app.routes.level_routes import level_routes  
    from app.routes.section_routes import section_routes 
    
    # Lista de Blueprints
    blueprints = [
        user_routes,
        title_routes,
        question_routes,
        answer_routes,
        prompt_routes,
        studymaterial_routes,
        level_routes,
        section_routes,
        test_routes,
        test_comments_routes,
        test_detail_routes,
        student_dashboard_routes,
        admin_dashboard_routes,
        questions_ai_routes
    ]
    
    # Registrar los Blueprints
    for bp in blueprints:
        app.register_blueprint(bp)
        
    
    return app
