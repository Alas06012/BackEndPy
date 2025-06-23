from flask import Blueprint
from app.controllers.admin_dashboard_controller import AdminDashboard

admin_dashboard_routes = Blueprint('admin_dashboard_routes', __name__)

admin_dashboard_routes.route('/admin-dashboard', methods=['GET'])(AdminDashboard.get_dashboard_data)
