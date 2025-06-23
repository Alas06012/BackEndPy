from flask import jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from app.models.user_model import Usuario
from app.models.admin_dashboard_model import AdminDashboardModel

class AdminDashboard:
    @staticmethod
    @jwt_required()
    def get_dashboard_data():
        """
        Retorna las estadísticas generales del dashboard del administrador.
        Solo accesible para usuarios con rol admin o teacher.
        """
        try:
            current_user_id = get_jwt_identity()
            user = Usuario.get_user_by_id(current_user_id)

            if not user or user.get('user_role') not in ['admin', 'teacher']:
                return jsonify({
                    "success": False,
                    "message": "Acceso denegado. No autorizado."
                }), 403

            dashboard_data = AdminDashboardModel.get_dashboard_data()
            print("DATOS ABAJO")
            print(dashboard_data)
            if dashboard_data is None:
                return jsonify({
                    "success": False,
                    "message": "No se pudieron recuperar los datos del dashboard"
                }), 404

            return jsonify({
                "success": True,
                "data": dashboard_data
            }), 200

        except Exception as e:
            return jsonify({
                "success": False,
                "message": f"Error al obtener datos del dashboard del admin: {str(e)}"
            }), 500
