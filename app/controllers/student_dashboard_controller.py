from app.models.student_dashboard_model import StudentDashboardModel
from app.models.user_model import Usuario
from flask import jsonify, request
from flask_jwt_extended import jwt_required, get_jwt_identity
from app import mysql

class StudentDashboard:
    @staticmethod
    @jwt_required()
    def get_dashboard_data():
        """
        Obtiene los datos del dashboard para el estudiante autenticado.
        """
        try:
            # Obtener el ID del usuario autenticado
            current_user_id = get_jwt_identity()
            user = Usuario.get_user_by_id(current_user_id)
    
            if not user or user.get('user_role') not in ['admin', 'teacher', 'student']:
                return jsonify({
                    "success": False,
                    "message": "Unauthorized User"
                }), 403

            # Obtener los datos del dashboard para el usuario
            dashboard_data = StudentDashboardModel.get_dashboard_data(user_id=current_user_id)
            
            if dashboard_data is None:
                return jsonify({
                    "success": False,
                    "data": False,
                    "message": "No se encontraron datos para el usuario"
                }), 404

            # Procesar test_history para limitarlo a 5 intentos si es necesario
            dashboard_data["test_history"] = dashboard_data["test_history"][:5] if dashboard_data["test_history"] else []

            return jsonify({
                "success": True,
                "data": dashboard_data
            }), 200

        except Exception as e:
            return jsonify({
                "success": False,
                "message": f"Error al obtener datos del dashboard: {str(e)}"
            }), 500