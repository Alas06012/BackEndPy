from flask import Blueprint
from app.controllers.user_controller import UserController


user_routes = Blueprint('user_routes', __name__)

#   AUTENTICACIÓN
#   ---------------------------
# 
# Ruta para registrar un usuario
user_routes.route('/create_test', methods=['POST'])(UserController.create_test)