import os
from datetime import timedelta

class Config:
    SECRET_KEY = os.environ.get('SECRET_KEY', 'O8C6SqE5BpXmGVT1ePg0GML7GDK0HkQa')
    MYSQL_HOST = os.environ.get('MYSQL_HOST', 'localhost')
    MYSQL_USER = os.environ.get('MYSQL_USER', 'root')
    MYSQL_PASSWORD = os.environ.get('MYSQL_PASSWORD', '')
    MYSQL_DB = os.environ.get('MYSQL_DB', 'default_db')
    MYSQL_CURSORCLASS = os.environ.get('MYSQL_CURSORCLASS', 'DictCursor')
    
    JWT_SECRET_KEY = os.environ.get('JWT_SECRET_KEY', 'fallback_jwt_secret')
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(minutes=15)
    JWT_REFRESH_TOKEN_EXPIRES = timedelta(days=30)
