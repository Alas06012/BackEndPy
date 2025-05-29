
from flask import Blueprint
from app.controllers.user_controller import UserController


user_routes = Blueprint('user_routes', __name__)

#   AUTENTICACIÓN
#   ---------------------------
# 
# Ruta para registrar un usuario
user_routes.route('/register', methods=['POST'])(UserController.register_user)
# Ruta para iniciar sesión (login)
user_routes.route('/login', methods=['POST'])((UserController.login_user))
# Ruta protegida para obtener información del usuario actual
user_routes.route('/auth/verify', methods=['GET'])(UserController.get_user_info)
# Endpoint para refrescar el access token
user_routes.route('/auth/refresh', methods=['POST'])(UserController.refresh_token)
# Endpoint para verificar codigo enviado al correo
user_routes.route('/verify-code', methods=['POST'])(UserController.verify_code)
# Endpoint para reenvio de codigo por correo
user_routes.route('/resend-code', methods=['POST'])(UserController.resend_code)



#   ADMINISTRACION DE USARIOS
#   ---------------------------
#   Se necesita rol de admin
#
# Create
user_routes.route('/users/create', methods=['POST'])(UserController.create_user)
# Delete
user_routes.route('/users/deactivate', methods=['DELETE'])(UserController.delete_user)
# ActivateUser
user_routes.route('/users/activate', methods=['PUT'])(UserController.activate_user)
# Edit
user_routes.route('/users/edit', methods=['PUT'])(UserController.edit_user)
# Edit
user_routes.route('/users', methods=['POST'])(UserController.get_filtered_users)

# Show active
#user_routes.route('/users/show/active', methods=['GET'])(UserController.get_active_users)
# Show inactive
#user_routes.route('/users/show/inactive', methods=['GET'])(UserController.get_inactive_users)
# # Search
# usuario_routes.route('/users/search', methods=['POST'])(UsuarioController.refresh_token)

