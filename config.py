import os
from dotenv import load_dotenv 
from datetime import timedelta

# Cargar variables del archivo .env
load_dotenv()

class Config:
    SECRET_KEY = os.getenv('SECRET_KEY', 'mi_clave_secreta')
    MYSQL_HOST = os.getenv('MYSQL_HOST', 'localhost')
    MYSQL_USER = os.getenv('MYSQL_USER', 'root')
    MYSQL_PASSWORD = os.getenv('MYSQL_PASSWORD', 'mi_contraseña')
    MYSQL_DB = os.getenv('MYSQL_DB', 'mi_basededatos')
    MYSQL_CURSORCLASS = os.getenv('MYSQL_CURSORCLASS', 'DictCursor')
    
    JWT_SECRET_KEY = os.getenv('JWT_SECRET_KEY', 'mi_jwt_secreto')
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(minutes=1)  # Expira en 30 minutos
    
