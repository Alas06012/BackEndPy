from app.models.test_comments_model import TestCommentsModel
from app.models.user_model import Usuario

from flask import json, jsonify, request
from flask_jwt_extended import create_access_token, jwt_required, get_jwt_identity
from flask_jwt_extended import jwt_required, get_jwt_identity, create_access_token
import pandas as pd
import bcrypt
from app import mysql
from dotenv import load_dotenv 
import time



# Cargar variables del archivo .env
load_dotenv()

class TestComments:
    
    @staticmethod
    @jwt_required()
    def add_comment_to_test():
        try:
            current_user_id = get_jwt_identity()
            user = Usuario.get_user_by_id(current_user_id)

            if user['user_role'] not in ['admin', 'teacher']:
                return jsonify({
                    "success": False,
                    "message": "Permisos insuficientes"
                }), 403

            req = request.get_json()
            test_id = req.get('test_id')
            comment_title = req.get('comment_title')
            comment_value = req.get('comment_value')

            if not test_id or not str(test_id).isdigit():
                return jsonify({"success": False, "message": "ID del test inválido"}), 400

            if not comment_value:
                return jsonify({"success": False, "message": "El comentario no puede estar vacío"}), 400

            inserted = TestCommentsModel.add_comment(test_id=int(test_id), user_id=current_user_id, comment_title=comment_title, comment_value=comment_value)

            if inserted:
                return jsonify({"success": True, "message": "Comentario agregado correctamente"}), 201
            else:
                return jsonify({"success": False, "message": "No se pudo agregar el comentario"}), 500

        except Exception as e:
            return jsonify({"error": str(e)}), 500
        
        
    @staticmethod
    @jwt_required()
    def get_comments_by_test():
        try:
            current_user_id = get_jwt_identity()
            user = Usuario.get_user_by_id(current_user_id)

            if user['user_role'] not in ['admin', 'teacher', 'student']:
                return jsonify({
                    "success": False,
                    "message": "Permisos insuficientes"
                }), 403

            req = request.get_json()
            test_id = req.get('test_id')

            if not test_id or not str(test_id).isdigit():
                return jsonify({"success": False, "message": "ID del test inválido"}), 400

            comments = TestCommentsModel.get_comments_by_test_id(int(test_id))

            print(comments)
            return jsonify({
                "success": True,
                "data": comments
            }), 200

        except Exception as e:
            return jsonify({
                "success": False,
                "message": f"Error al obtener comentarios: {str(e)}"
            }), 500
            
            
    @staticmethod
    @jwt_required()
    def edit_comment():
        try:
            current_user_id = get_jwt_identity()
            user = Usuario.get_user_by_id(current_user_id)

            if user['user_role'] not in ['admin', 'teacher']:
                return jsonify({
                    "success": False,
                    "message": "Permisos insuficientes"
                }), 403

            req = request.get_json()
            comment_id = req.get('comment_id')
            new_title = req.get('comment_title')
            new_value = req.get('comment_value')

            if not comment_id or not str(comment_id).isdigit():
                return jsonify({"success": False, "message": "ID del comentario inválido"}), 400
            if not new_value:
                return jsonify({"success": False, "message": "El nuevo comentario no puede estar vacío"}), 400

            updated = TestCommentsModel.update_comment_by_id(
                comment_id=int(comment_id),
                user_id=current_user_id,
                new_title=new_title,
                new_value=new_value
            )

            if updated:
                return jsonify({"success": True, "message": "Comentario actualizado correctamente"}), 200
            else:
                return jsonify({"success": False, "message": "No se pudo actualizar el comentario o no tiene permisos"}), 404

        except Exception as e:
            return jsonify({
                "success": False,
                "message": f"Error al actualizar comentario: {str(e)}"
            }), 500
