import os
from datetime import timedelta

if os.environ.get("ENV") != "cloud":
    from dotenv import load_dotenv
    load_dotenv()

class Config:
    # Configuración común
    SECRET_KEY = os.getenv('SECRET_KEY', 'fallback_secret')
    MYSQL_HOST = os.getenv('MYSQL_HOST', 'localhost')
    MYSQL_USER = os.getenv('MYSQL_USER', 'root')
    MYSQL_PASSWORD = os.getenv('MYSQL_PASSWORD', '')
    MYSQL_DB = os.getenv('MYSQL_DB', 'default_db')
    MYSQL_CURSORCLASS = os.getenv('MYSQL_CURSORCLASS', 'DictCursor')
    JWT_SECRET_KEY = os.getenv('JWT_SECRET_KEY', 'fallback_jwt_secret')
    
    # Configuración específica de Cloud
    DEEPSEEK_APIKEY = os.getenv('DEEPSEEK_APIKEY', '')
    GCS_BUCKET_NAME = os.getenv('GCS_BUCKET_NAME', '')
    #GOOGLE_APPLICATION_CREDENTIALS = os.getenv('GOOGLE_APPLICATION_CREDENTIALS', '')
    
    # Tokens JWT (ajustables por entorno)
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(hours=3)
    JWT_REFRESH_TOKEN_EXPIRES = timedelta(days=30)
    
    # Configuración de email
    MAIL_SERVER = os.getenv('MAIL_SERVER', 'smtp.gmail.com')
    MAIL_USERNAME = os.getenv('MAIL_USERNAME', '')
    MAIL_PASSWORD = os.getenv('MAIL_PASSWORD', '')
    MAIL_PORT = int(os.getenv('MAIL_PORT', 587))
    MAIL_USE_TLS = os.getenv('MAIL_USE_TLS', 'True') == 'True'
    MAIL_USE_SSL = os.getenv('MAIL_USE_SSL', 'False') == 'False'
    MAIL_DEFAULT_SENDER = (os.getenv('MAIL_SENDER_NAME', ''), os.getenv('MAIL_SENDER_EMAIL', ''))
