from flask import Blueprint
from app.controllers.student_dashboard_controller import StudentDashboard

student_dashboard_routes = Blueprint('student_dashboard_routes', __name__)

# Ruta para obtener los datos del dashboard del estudiante
student_dashboard_routes.route('/student-dashboard', methods=['GET'])(StudentDashboard.get_dashboard_data)