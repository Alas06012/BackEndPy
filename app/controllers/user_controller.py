import re
from app.models.user_model import Usuario
from flask import jsonify, request
from flask_jwt_extended import create_access_token, jwt_required, get_jwt_identity
from flask_jwt_extended import jwt_required, get_jwt_identity, create_access_token, create_refresh_token
import bcrypt
import random
from flask_mail import Message
from app import mail
from flask_limiter import Limiter
from flask import current_app
from datetime import datetime, timedelta
import secrets

MAX_ATTEMPTS = 5
BLOCK_MINUTES = 15

class UserController:

    @staticmethod
    def generate_code():
        return str(random.randint(100000, 999999))
    
    @staticmethod
    def send_verification_email(to, code):
        verification_link = f"http://localhost:5173/verify-code"
        
        msg = Message('🔐 Verify Your Email', recipients=[to])
        
        msg.html = f"""
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; padding: 20px; border: 1px solid #e2e2e2; border-radius: 10px;">
            <h2 style="color: #4b7af0;">Welcome to NECDiagnostics!</h2>
            <p style="font-size: 16px; color: #333;">Thank you for registering. To complete your registration, please verify your email address using the verification code below:</p>
            
            <div style="font-size: 24px; font-weight: bold; color: #4b7af0; margin: 20px 0;">{code}</div>
            
            <p style="font-size: 16px; color: #333;">You can enter this code on the verification page by clicking the button below:</p>
            
            <a href="{verification_link}" style="display: inline-block; padding: 10px 20px; background-color: #4b7af0; color: white; text-decoration: none; border-radius: 5px;">
                Verify Your Email
            </a>
            
            <p style="font-size: 14px; color: #777; margin-top: 30px;">If you did not request this, please ignore this email.</p>
            <p style="font-size: 14px; color: #aaa;">&copy; 2025 NECDiagnostics</p>
        </div>
        """

        mail.send(msg)
        
        
    @staticmethod
    def send_password_reset_email(to, token):
        reset_link = f"http://localhost:5173/reset-password?token={token}"

        msg = Message('🔐 Reset Your Password', recipients=[to])
        
        msg.html = f"""
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; padding: 20px; border: 1px solid #e2e2e2; border-radius: 10px;">
            <h2 style="color: #4b7af0;">Password Reset Request</h2>
            <p style="font-size: 16px; color: #333;">We received a request to reset your password. If you didn’t make this request, you can safely ignore this email.</p>
            
            <p style="font-size: 16px; color: #333;">Click the button below to create a new password:</p>
            
            <a href="{reset_link}" style="display: inline-block; padding: 10px 20px; background-color: #4b7af0; color: white; text-decoration: none; border-radius: 5px; margin: 20px 0;">
                Reset Your Password
            </a>

            <p style="font-size: 14px; color: #777;">This link will expire in 1 hour for security reasons.</p>
            <p style="font-size: 14px; color: #aaa;">&copy; 2025 NECDiagnostics</p>
        </div>
        """

        mail.send(msg)


    
    @staticmethod
    def register_user():
        data = request.get_json()
        name = data.get('name')
        lastname = data.get('lastname')
        carnet = data.get('carnet')
        email = data.get('email')
        role = 'student'
        password = data.get('password')

        if not email or not password or not name or not lastname or not carnet:
            return jsonify({"message": "Please complete all required fields"}), 400

        # Hashear la contraseña antes de guardarla
        hashed_password = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt())
        
        #Generar codigo para doble autenticacion
        code = UserController.generate_code()
        
        # Crear el usuario en la base de datos
        response = Usuario.create_user(name, lastname, carnet, email, role, hashed_password.decode('utf-8'), code, is_verified=False)
        
        if response == 'True':
            try:
                email_sent = UserController.send_verification_email(email, code)
            except Exception:
                 return jsonify({
                    "message": "User created - Email for verification code was not sent. Please try resending."
                }), 201
            
            if email_sent:
                return jsonify({
                    "message": "User created - Check your email for the verification code"
                }), 201
            else:
                return jsonify({
                    "message": "User created - Email for verification code was not sent. Please try resending."
                }), 201

        elif 'duplicate entry' in str(response).lower():
            return jsonify({"error": "The email or student ID is already registered"}), 400

        else:
            return jsonify({"error": "Registration failed due to an error"}), 400
        

    @staticmethod
    def verify_code():
        data = request.get_json()
        email = data.get('email')
        code = data.get('code')
        
        if not email or not code:
            return jsonify({"message": "Please complete all required fields"}), 400

        result = Usuario.activate_user_by_code(email, code)

        if result:
            return jsonify({"message": "Email verified successfully."}), 200
        else:
            return jsonify({"error": "Invalid verification code"}), 400
        
        
    @staticmethod
    def resend_code():
        data = request.get_json()
        email = data.get('email')

        if not email:
            return jsonify({"message": "Email is required"}), 400

        email_regex = r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
        if not re.match(email_regex, email):
            return jsonify({"message": "Invalid email format"}), 400

        user = Usuario.get_user_by_email(email=email, status='PENDING')

        if not user:
            return jsonify({"message": "User not found"}), 404

        if user['is_verified']:
            return jsonify({"message": "This account is already verified."}), 400

        # Antispam: esperar 1 minuto entre envíos
        last_sent = user.get('last_code_sent_at')
        if last_sent:
            if isinstance(last_sent, str):
                last_sent = datetime.strptime(last_sent, "%Y-%m-%d %H:%M:%S") 
            if datetime.now() - last_sent < timedelta(minutes=3):
                return jsonify({"message": "Please wait 3 minutes before requesting another code."}), 429

        new_code = UserController.generate_code()

        update_result = Usuario.update_verification_code(email, new_code)
        if update_result is not True:
            return jsonify({"message": "Failed to update verification code."}), 500

        UserController.send_verification_email(email, new_code)

        return jsonify({"message": "Verification code resent successfully."}), 200



    @staticmethod
    def login_user():
        data = request.get_json()
        email = data.get('email')
        password = data.get('password')
        ip = request.remote_addr

        if not email or not password:
            return jsonify({"message": "Email and password are required"}), 400

        attempt = Usuario.get_ip_attempts(ip)

        now = datetime.now()

        # Si está bloqueado actualmente
        if attempt and attempt['blocked_until'] and attempt['blocked_until'] > now:
            minutes_left = int((attempt['blocked_until'] - now).total_seconds() / 60)
            return jsonify({"message": f"Too many failed attempts. Try again in {minutes_left} minute(s)."}), 429

        # Validar usuario
        user = Usuario.get_user_by_email(email)

        if user:
            if not user['is_verified']:
                return jsonify({"message": "Account not verified. Please verify your email."}), 403

            if bcrypt.checkpw(password.encode('utf-8'), user['user_password'].encode('utf-8')):
                # Login correcto: limpiar intentos por IP
                Usuario.clean_ip_attempts(ip)
                
                access_token = create_access_token(identity=str(user['pk_user']))
                refresh_token = create_refresh_token(identity=str(user['pk_user']))

                return jsonify({
                    "access_token": access_token,
                    "refresh_token": refresh_token,
                    "user": {
                        "id": user['pk_user'],
                        "name": user['user_name'],
                        "lastname": user['user_lastname'],
                        "email": user['user_email'],
                        "role": user['user_role']
                    }
                }), 200

        # Fallo: actualizar o insertar intento
        if attempt:
            new_count = attempt['failed_count'] + 1
            blocked_until = now + timedelta(minutes=BLOCK_MINUTES) if new_count >= MAX_ATTEMPTS else None
            
            Usuario.update_ip_attempt(new_count, now, blocked_until, ip)
        else:
            Usuario.insert_ip_attempt(ip_address=ip, failed_count=1, last_attempt=now, blocked_until=None)
            
        return jsonify({"message": "Invalid email or password"}), 401
    
    

    @staticmethod
    def forgot_password():
        data = request.get_json()
        email = data.get("email")

        if not email:
            return jsonify({"message": "Email is required"}), 400

        user = Usuario.get_user_by_email(email)

        if not user:
            return jsonify({"message": "User not found or not verified"}), 404

        token = secrets.token_urlsafe(64)
        expires_at = datetime.now() + timedelta(hours=1)

        Usuario.insert_password_change_token(user['pk_user'], token, expires_at)

        # Enviar correo
        UserController.send_password_reset_email(to=email, token=token)

        return jsonify({"message": "An email has been sent to reset your password."}), 200


    
    @staticmethod
    def reset_password():
        data = request.get_json()
        token = data.get("token")
        new_password = data.get("new_password")

        if not token or not new_password:
            return jsonify({"message": "Token and new password are required"}), 400
        
        if len(new_password) < 8:
            return jsonify({"message": "Password must be at least 8 characters long"}), 400

        pw_token = Usuario.get_password_change_token(token)
        
        if not pw_token:
            return jsonify({"message": "Invalid or expired token"}), 400

        if datetime.now() > pw_token['expires_at']:
            return jsonify({"message": "Token expired"}), 400

        hashed_pw = bcrypt.hashpw(new_password.encode('utf-8'), bcrypt.gensalt())
        
        result = Usuario.change_password_with_token(hashed_pw=hashed_pw, user_id= pw_token['user_id'], token=token)
     
        if result:
            return jsonify({"message": "Password updated successfully"}), 200
        else:
            return jsonify({"message": "An Error ocurred while updating password"}), 400


        

    @staticmethod
    @jwt_required()
    def get_user_info():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)

        if user:
            return jsonify(
                {
                    "id": user['pk_user'],  
                    "name": user['user_name'],  
                    "lastname": user['user_lastname'], 
                    "email": user['user_email'],
                    "role": user['user_role']
                }), 200

        # Usuario no existe -> devolvemos 401 
        return jsonify({"message": "Unauthorized"}), 401
    
    
    @staticmethod
    @jwt_required(refresh=True)
    def refresh_token():
        current_user_id = get_jwt_identity()
        new_token = create_access_token(identity=current_user_id)
        return jsonify(access_token=new_token), 200
    
    
    
    
    #METODO CREAR USUARIO
    #--------------------
    # UNICAMENTE VALIDO PARA USUARIOS ADMIN
    #
    @staticmethod
    @jwt_required()
    def create_user():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)
        
        if user['user_role'] != 'admin':
            return jsonify({"message": "The user is not authorized to create other users"}), 404
        
        data = request.get_json()
        name = data.get('name')
        lastname = data.get('lastname')
        carnet = data.get('carnet')
        email = data.get('email')
        role = 'student'
        password = data.get('password')
        
        
        if not email or not password or not name or not lastname or not carnet:
            return jsonify({"message": "Please complete all required fields"}), 400

        # Hashear la contraseña antes de guardarla
        hashed_password = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt())
        
        # Crear el usuario en la base de datos
        response = Usuario.create_user(name, lastname, carnet, email, role, hashed_password.decode('utf-8'))
        
        if response == 'True':
            return jsonify({"message": "The user was successfully created"}), 201
        elif 'duplicate entry' in str(response).lower(): 
            return jsonify({"error": "The email or student ID is already registered"}), 400
        else:
            return jsonify({"error": "Registration failed due to an error"}), 400
        
        
    #METODO ELIMINAR USUARIO
    #--------------------
    # UNICAMENTE VALIDO PARA USUARIOS ADMIN
    #
    @staticmethod
    @jwt_required()
    def delete_user():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)
        
        if user['user_role'] != 'admin':
            return jsonify({"message": "The user is not authorized to delete other users"}), 404
        
        data = request.get_json()
        email = data.get('email')
        
        if not email:
            return jsonify({"message": "Please complete all required fields"}), 400

        # Crear el usuario en la base de datos
        response = Usuario.delete_user(email)
        
        if response == 'True':
            return jsonify({"message": "User successfully deactivated"}), 201
        elif 'duplicate entry' in str(response).lower(): 
            return jsonify({"error": "The email or student ID is already registered."}), 400
        else:
            return jsonify({"error": "Failed to delete the user. An error occurred"}), 400
        
        
     #METODO ACTIVAR USUARIO
    #--------------------
    # UNICAMENTE VALIDO PARA USUARIOS ADMIN
    #
    @staticmethod
    @jwt_required()
    def activate_user():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)
        
        if user['user_role'] != 'admin':
            return jsonify({"message": "The user is not authorized to activate other users."}), 404
        
        data = request.get_json()
        email = data.get('email')
        
        if not email:
            return jsonify({"message": "Please complete all required fields"}), 400

        # Crear el usuario en la base de datos
        response = Usuario.activate_user(email)
              
        if response == 'True':
            return jsonify({"message": "The user was successfully activated"}), 201
        elif 'duplicate entry' in str(response).lower(): 
            return jsonify({"error": "The email or student ID is already registered"}), 400
        else:
            return jsonify({"error": "Activation failed due to an error"}), 400
        
        
    #METODO EDITAR USUARIO
    #--------------------
    # UNICAMENTE VALIDO PARA USUARIOS ADMIN
    #
    @staticmethod
    @jwt_required()
    def edit_user():
        current_user_id = get_jwt_identity()
        user = Usuario.get_user_by_id(current_user_id)
        
        if user['user_role'] != 'admin':
            return jsonify({"message": "The user is not authorized to edit other users"}), 404
        
        data = request.get_json()
        name = data.get('name')
        lastname = data.get('lastname')
        carnet = data.get('carnet')
        current_email = data.get('current_email')
        new_email = data.get('new_email')
        role = data.get('role')
        
        if not current_email or not name or not lastname or not carnet or not role:
            return jsonify({"message": "Please complete all required fields"}), 400
        elif not new_email :
            # Editar el usuario en la base de datos
            response = Usuario.edit_user(name, lastname, carnet, role, current_email)
        else:
             # Editar el usuario en la base de datos
            response = Usuario.edit_user(name, lastname, carnet, role, current_email, new_email)
               
        if response == 'True':
            return jsonify({"message": "The user was successfully modified"}), 201
        elif 'duplicate entry' in str(response).lower(): 
            return jsonify({"error": "The email or student ID is already registered"}), 400
        else:
            return jsonify({"error": "Action modify failed due to an error"}), 400
        

    @staticmethod
    @jwt_required()
    def get_filtered_users():
        try:
            current_user_id = get_jwt_identity()
            user = Usuario.get_user_by_id(current_user_id)

            if user['user_role'] != 'admin':
                return jsonify({"message": "The user is not authorized to fetch users data"}), 403

            data = request.get_json() or {}
            page = data.get('page', 1)
            per_page = data.get('per_page', 20)

            filters = {
                "user_email": data.get("user_email"),
                "user_name": data.get("user_name"),
                "user_lastname": data.get("user_lastname"),
                "user_carnet": data.get("user_carnet"),
                "user_role": data.get("user_role"),
                "status": data.get("status")
            }

            paginated_results = Usuario.get_paginated_users(
                filters=filters,
                page=page,
                per_page=per_page
            )

            if isinstance(paginated_results, str):
                return jsonify({"error": "Error in database", "details": paginated_results}), 500

            response = {
                "users": paginated_results['data'],
                "pagination": {
                    "total_items": paginated_results['total'],
                    "total_pages": paginated_results['pages'],
                    "current_page": page,
                    "items_per_page": per_page
                },
                "applied_filters": {k: v for k, v in filters.items() if v}
            }

            return jsonify(response), 200

        except Exception as e:
            return jsonify({"error": "Exception", "details": str(e)}), 500
       
       


