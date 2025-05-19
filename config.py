import os
from dotenv import load_dotenv 
from datetime import timedelta

# Cargar variables del archivo .env
load_dotenv()

class Config:
    SECRET_KEY = os.getenv('SECRET_KEY', 'O8C6SqE5BpXmGVT1ePg0GML7GDK0HkQa')
    MYSQL_HOST = os.getenv('MYSQL_HOST', 'host.docker.internal')
    MYSQL_USER = os.getenv('MYSQL_USER', 'root')
    MYSQL_PASSWORD = os.getenv('MYSQL_PASSWORD', '')
    MYSQL_DB = os.getenv('MYSQL_DB', 'nec_diagnostics_db')
    #MYSQL_PORT = os.getenv('MYSQL_PORT', '3306')
    MYSQL_CURSORCLASS = os.getenv('MYSQL_CURSORCLASS', 'DictCursor')
    DEEPSEEK_APIKEY = os.getenv('DEEPSEEK_APIKEY', '123456')
    GCS_BUCKET_NAME = os.getenv('GCS_BUCKET_NAME', 'tesisdev-bucket')
    GOOGLE_APPLICATION_CREDENTIALS = os.getenv('GOOGLE_APPLICATION_CREDENTIALS', 'storage-tesis.json')
    JWT_SECRET_KEY = os.getenv('JWT_SECRET_KEY', 'O8C6SqE5BpXmGVT1ePg0GML7GDK0HkQb')
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(minutes=15)
    JWT_REFRESH_TOKEN_EXPIRES = timedelta(days=30)
