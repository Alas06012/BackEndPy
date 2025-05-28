from flask import current_app
from google.cloud import storage
from config import Config
import uuid
from datetime import timedelta
from werkzeug.utils import secure_filename

#Generar diagrama UML

def upload_file_to_gcs(file):
    try:
        client = storage.Client()
        bucket = client.bucket(Config.GCS_BUCKET_NAME)
        
        # Generar nombre único seguro
        filename = f"{uuid.uuid4()}-{secure_filename(file.filename)}"
        blob = bucket.blob(filename)
        
        # Configurar tipo de contenido
        blob.content_type = file.content_type
        
        # Subir el archivo (solo una vez)
        blob.upload_from_file(file)
        
        # URL pública directa (no firmada)
        public_url = f"https://storage.googleapis.com/{Config.GCS_BUCKET_NAME}/{blob.name}"
        
        return public_url
    except Exception as e:
        current_app.logger.error(f"GCS Upload Error: {str(e)}")
        raise Exception(f"Error uploading file: {str(e)}")