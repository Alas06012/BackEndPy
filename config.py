import os
from dotenv import load_dotenv 
from datetime import timedelta

# Cargar variables del archivo .env
load_dotenv()

class Config:
    SECRET_KEY = os.getenv('SECRET_KEY', 'O8C6SqE5BpXmGVT1ePg0GML7GDK0HkQa')
    MYSQL_HOST = os.getenv('MYSQL_HOST', 'host.docker.internal')
    MYSQL_USER = os.getenv('MYSQL_USER', 'admin')
    MYSQL_PASSWORD = os.getenv('MYSQL_PASSWORD', '')
    #MYSQL_PORT = os.getenv('MYSQL_PORT', '3306')
    MYSQL_DB = os.getenv('MYSQL_DB', 'nec_diagnostics_db')
    MYSQL_CURSORCLASS = os.getenv('MYSQL_CURSORCLASS', 'DictCursor')
    DEEPSEEK_APIKEY = os.getenv('DEEPSEEK_APIKEY', 'sk-87774b3c876145028ab40f0d01fd158f')
    GCS_BUCKET_NAME = os.getenv('GCS_BUCKET_NAME', 'tesisdev-bucket')
    GOOGLE_APPLICATION_CREDENTIALS = os.getenv('GOOGLE_APPLICATION_CREDENTIALS', 'storage-tesis.json')
    JWT_SECRET_KEY = os.getenv('JWT_SECRET_KEY', 'O8C6SqE5BpXmGVT1ePg0GML7GDK0HkQb')
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(hours=3) #3 horas activo y luego expira
    JWT_REFRESH_TOKEN_EXPIRES = timedelta(days=30)
    
    # Configuración de Flask-Mail
    MAIL_SERVER = os.getenv('MAIL_SERVER', '') # o tu proveedor SMTP
    MAIL_USERNAME = os.getenv('MAIL_USERNAME', '')
    MAIL_PASSWORD = os.getenv('MAIL_PASSWORD', '')
    MAIL_PORT = os.getenv('MAIL_PORT', '')
    MAIL_USE_TLS = False
    MAIL_USE_SSL = True
    MAIL_DEFAULT_SENDER = ('NecDiagnostics' ,'no.reply@necdiagnostics.online')
    
    ALLOWED_ORIGINS = os.getenv('ALLOWED_ORIGINS', 'http://localhost:5173')
    
