from app.models.questions_model import Questions
from app.models.title_model import QuestionTitle
from app.models.user_model import Usuario
from flask import jsonify, request
from flask_jwt_extended import create_access_token, jwt_required, get_jwt_identity
from flask_jwt_extended import jwt_required, get_jwt_identity, create_access_token
import bcrypt
from google.cloud import texttospeech, storage
from flask import current_app
import uuid
from datetime import datetime

class TitleController:
    
    #METODO CREAR STORY (question_title)  ASEGURAR LA GENERACION DEL UML DEL PROCESO DE GENERACION DE VOZ
    #-----------------------------------------
    # UNICAMENTE VALIDO PARA USUARIOS ADMIN
    #
    @staticmethod
    @jwt_required()
    def create_story():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)
        
        if user['user_role'] != 'admin':
            return jsonify({"message": "Permisos insuficientes"}), 403
        
        data = request.get_json()
        title = data.get('title')
        content = data.get('content')
        type_ = data.get('type')
        
        if not content or not title or not type_:
            return jsonify({"message": "Datos incompletos"}), 400

        if type_ != 'LISTENING' and type_ != 'READING':
            return jsonify({"message": "Tipo debe ser LISTENING o READING"}), 400

        audio_url = None  # Valor por defecto

        try:
            if type_ == 'LISTENING':
                # Generar SSML solo para LISTENING
                VOICE_MAPPING = {
                    'person 1': 'en-US-Standard-I',
                    'person 2': 'en-US-Standard-H',
                    'person 3': 'en-US-Standard-C',
                    'person 4': 'en-US-Standard-D',
                    'default': 'en-US-Standard-B'
                }

                ssml = ['<speak>']
                previous_speaker = None
                
                for line in content.split('\n'):
                    line = line.strip()
                    if not line:
                        continue
                        
                    current_speaker = None
                    text_to_speak = ""
                    
                    if ': ' in line:
                        speaker, text = line.split(': ', 1)
                        speaker_key = speaker.strip().lower()
                        current_speaker = speaker_key
                        voice_name = VOICE_MAPPING.get(speaker_key, VOICE_MAPPING['default'])
                        text_to_speak = text.strip()
                    else:
                        current_speaker = 'narration'
                        voice_name = VOICE_MAPPING['default']
                        text_to_speak = line.strip()
                    
                    # Agregar fade-out de 100ms al final de cada intervención
                    ssml.append(
                        f'<voice name="{voice_name}">'
                        f'{text_to_speak}'
                        '<break time="200ms"/></voice>'  # Fade-out suave
                    )
                    
                    # Pausa más larga solo entre cambios de speaker
                    if previous_speaker and previous_speaker != current_speaker:
                        ssml.append('<break time="500ms"/>')  # Pausa contextual
                        
                    previous_speaker = current_speaker
                
                ssml.append('</speak>')
                ssml = ''.join(ssml)

                # Generar audio
                tts_client = texttospeech.TextToSpeechClient()
                synthesis_input = texttospeech.SynthesisInput(ssml=ssml)
                voice = texttospeech.VoiceSelectionParams(
                    language_code="en-US",
                    name="en-US-Standard-B"
                )
                audio_config = texttospeech.AudioConfig(
                    audio_encoding=texttospeech.AudioEncoding.MP3
                )
                response = tts_client.synthesize_speech(
                    input=synthesis_input,
                    voice=voice,
                    audio_config=audio_config
                )

                # Subir a Google Cloud Storage
                storage_client = storage.Client()
                bucket = storage_client.bucket(current_app.config['GCS_BUCKET_NAME'])
                filename = f"audios/{datetime.now().strftime('%Y%m%d')}-{uuid.uuid4().hex}.mp3"
                blob = bucket.blob(filename)

                blob.upload_from_string(
                    response.audio_content,
                    content_type='audio/mpeg'
                )
                audio_url = f"https://storage.googleapis.com/{current_app.config['GCS_BUCKET_NAME']}/{blob.name}"

        except Exception as e:
            return jsonify({"error": str(e)}), 500

        # Guardar en base de datos (audio_url será None para READING)
        response = QuestionTitle.create_title(title, content, type_, audio_url)
        
        if response == 'True':
            return jsonify({
                "message": "Historia creada",
                "audio_url": audio_url if audio_url else "No aplica para READING"
            }), 201
        else:
            # Eliminar audio si falló la inserción y era LISTENING
            if type_ == 'LISTENING' and audio_url:
                try:
                    blob.delete()
                except:
                    pass
            return jsonify({"error": response}), 400
        
        
    #METODO EDITAR TITLES 
    #--------------------
    # UNICAMENTE VALIDO PARA USUARIOS ADMIN
    #
    @staticmethod
    @jwt_required()
    def edit_title():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)

        if user['user_role'] not in ['admin', 'teacher']:
            return jsonify({"message": "El usuario no tiene permisos necesarios."}), 403

        data = request.get_json()

        id_ = data.get('id')
        new_content = data.get('content')
        new_type = data.get('type')
        new_status = data.get('status')
        new_title = data.get('title')
        
        if not id_:
            return jsonify({"error": "ID requerido"}), 400

        # Obtener el título actual
        current_title = QuestionTitle.get_title_by_id(id_)
        if not current_title:
            return jsonify({"error": "Título no encontrado"}), 404

        # Validar tipo
        if new_type and new_type not in ['LISTENING', 'READING']:
            return jsonify({"error": "Tipo inválido"}), 400

        # Mapeo de campos
        field_mapping = {
            "title": "title_name",
            "content": "title_test",
            "type": "title_type",
            "url": "title_url",
            "status": "status"
        }

        update_fields = {}
        audio_url = None
        old_audio_url = current_title['title_url']
        delete_old_audio = False

        try:
            # Lógica de generación de audio solo si es necesario
            if new_type == 'LISTENING' or current_title['title_type'] == 'LISTENING':
                if new_content or (new_type and new_type != current_title['title_type']):
                    # Regenerar audio si:
                    # 1. Cambia el contenido
                    # 2. Cambia el tipo de READING a LISTENING
                    
                    VOICE_MAPPING = {
                        'person 1': 'en-US-Standard-I',
                        'person 2': 'en-US-Standard-H',
                        'person 3': 'en-US-Standard-C',
                        'person 4': 'en-US-Standard-D',
                        'default': 'en-US-Standard-B'
                    }

                    ssml = ['<speak>']
                    content_to_process = new_content if new_content else current_title['title_test']
                    
                    for line in content_to_process.split('\n'):
                        line = line.strip()
                        if not line:
                            continue
                            
                        if ': ' in line:
                            speaker, text = line.split(': ', 1)
                            speaker_key = speaker.strip().lower()
                            voice_name = VOICE_MAPPING.get(speaker_key, VOICE_MAPPING['default'])
                            ssml.append(f'<voice name="{voice_name}">{text.strip()}<break time="100ms"/></voice>')
                        else:
                            ssml.append(f'<voice name="{VOICE_MAPPING["default"]}">{line.strip()}<break time="100ms"/></voice>')
                    
                    ssml.append('</speak>')
                    ssml = ''.join(ssml)

                    # Generar nuevo audio
                    tts_client = texttospeech.TextToSpeechClient()
                    response = tts_client.synthesize_speech(
                        input=texttospeech.SynthesisInput(ssml=ssml),
                        voice=texttospeech.VoiceSelectionParams(
                            language_code="en-US",
                            name="en-US-Standard-B"
                        ),
                        audio_config=texttospeech.AudioConfig(
                            audio_encoding=texttospeech.AudioEncoding.MP3
                        )
                    )

                    # Subir a GCS
                    storage_client = storage.Client()
                    bucket = storage_client.bucket(current_app.config['GCS_BUCKET_NAME'])
                    filename = f"audios/{datetime.now().strftime('%Y%m%d')}-{uuid.uuid4().hex}.mp3"
                    blob = bucket.blob(filename)
                    blob.upload_from_string(response.audio_content, content_type='audio/mpeg')
                    audio_url = f"https://storage.googleapis.com/{current_app.config['GCS_BUCKET_NAME']}/{blob.name}"
                    delete_old_audio = True

            # Manejar cambio a READING
            if new_type == 'READING' and current_title['title_type'] == 'LISTENING':
                audio_url = None
                delete_old_audio = True

            # Construir campos de actualización
            if new_title:
                update_fields['title_name'] = new_title
            if new_content:
                update_fields['title_test'] = new_content
            if new_type:
                update_fields['title_type'] = new_type
            if new_status:
                update_fields['status'] = new_status
            if audio_url is not None:
                update_fields['title_url'] = audio_url

            # Actualizar en base de datos
            if update_fields:
                response = QuestionTitle.edit_title(id_, **update_fields)
            else:
                return jsonify({"message": "Sin cambios para actualizar"}), 200

            # Eliminar audio antiguo después de actualización exitosa
            if delete_old_audio and old_audio_url:
                try:
                    blob_name = old_audio_url.split(current_app.config['GCS_BUCKET_NAME'] + '/')[-1]
                    bucket = storage_client.bucket(current_app.config['GCS_BUCKET_NAME'])
                    blob = bucket.blob(blob_name)
                    blob.delete()
                except Exception as e:
                    current_app.logger.error(f"Error eliminando audio antiguo: {str(e)}")

            # Manejar estado de preguntas
            if new_status == 'INACTIVE':
                QuestionTitle.deactivate_questions_per_title(id_)
            elif new_status == 'ACTIVE':
                QuestionTitle.activate_questions_per_title(id_)

            if response == 'True':
                return jsonify({"message": "Actualización exitosa"}), 200
            else:
                return jsonify({"error": response}), 400

        except Exception as e:
            # Eliminar audio nuevo si hubo error
            if audio_url:
                try:
                    blob.delete()
                except:
                    pass
            return jsonify({"error": str(e)}), 500
    
    
    
    #METODO BORRAR TITLES
    #----------------------------------------------
    # Desactiva un título y sus preguntas asociadas.
    #  Solo accesible por usuarios con rol 'admin'.
    #
    @staticmethod
    @jwt_required()
    def deactivate_title(): 
        try:
            current_user_id = get_jwt_identity()
            user = Usuario.get_user_by_id(current_user_id)

            # Verificación de permisos
            if not user or user.get('user_role') not in ['admin', 'teacher']:
                return jsonify({"message": "El usuario no tiene permisos necesarios."}), 403

            # Obtener ID desde el body
            data = request.get_json()
            id_ = data.get('id')

            if not id_:
                return jsonify({"error": "El ID del título es requerido."}), 400

            # Inactivar título y preguntas relacionadas
            success_title = QuestionTitle.delete_title(id_)
            success_questions = QuestionTitle.deactivate_questions_per_title(title_id=id_)

            if success_title == 'True' and success_questions == 'True':
                return jsonify({"message": "Encabezado y preguntas desactivados correctamente."}), 200

            return jsonify({
                "error": "No se pudo desactivar el encabezado o sus preguntas.",
                "detalle": {
                    "encabezado": success_title,
                    "preguntas": success_questions
                }
            }), 400

        except Exception as e:
            return jsonify({"error": "Error interno del servidor", "detalle": str(e)}), 500
        
        
        
    @staticmethod
    @jwt_required()
    def get_filtered_titles():
        try:
            # Validación de permisos
            current_user_id = get_jwt_identity()
            user = Usuario.get_user_by_id(current_user_id)
            if user['user_role'] not in ['admin', 'teacher']:
                return jsonify({"message": "Acceso denegado: Usuario sin privilegios suficientes"}), 403

            # Parámetros del body con valores por defecto
            data = request.get_json() or {}
            page = data.get('page', 1)
            per_page = data.get('per_page', 20)
            status = data.get('status', 'Todos')
            title_type = data.get('title_type')  
            title_name = data.get('title_name')
            print("title_name:", data.get('title_name'))
 
            # Validación de paginación
            if page < 1 or per_page < 1:
                return jsonify({"error": "Los parámetros de paginación deben ser ≥ 1"}), 400
            if per_page > 100:
                per_page = 100

            # Llamar al modelo
            paginated_results = QuestionTitle.get_paginated_titles(
                title_name = title_name,
                status = status,
                title_type = title_type,
                page = page,
                per_page = per_page
            )

            if isinstance(paginated_results, str):
                return jsonify({"error": "Error en la base de datos", "details": paginated_results}), 500

            # Construcción de la respuesta
            response = {
                "titles": paginated_results['data'],
                "pagination": {
                    "total_items": paginated_results['total'],
                    "total_pages": paginated_results['pages'],
                    "current_page": page,
                    "items_per_page": per_page
                }
            }

            # Filtros aplicados
            if title_type:
                response["applied_filters"] = {"title_type": title_type}

            return jsonify(response), 200

        except Exception as e:
            return jsonify({"error": "Error interno", "details": str(e)}), 500
        
        

    
    
