
from flask import Blueprint
from app.controllers.usuario_controller import UsuarioController


usuario_routes = Blueprint('usuario_routes', __name__)

# Ruta para registrar un usuario
usuario_routes.route('/register', methods=['POST'])(UsuarioController.register_user)

# Ruta para iniciar sesión (login)
usuario_routes.route('/login', methods=['POST'])((UsuarioController.login_user))

# Ruta protegida para obtener información del usuario actual
usuario_routes.route('/auth/verify', methods=['GET'])(UsuarioController.get_user_info)

# Endpoint para refrescar el access token
usuario_routes.route('/auth/refresh', methods=['POST'])(UsuarioController.refresh_token)



# Create
usuario_routes.route('/users/create', methods=['POST'])(UsuarioController.create_user)
# Delete
usuario_routes.route('/users/delete', methods=['POST'])(UsuarioController.delete_user)
# Edit
usuario_routes.route('/users/edit', methods=['POST'])(UsuarioController.edit_user)
# Show active
usuario_routes.route('/users/show/active', methods=['GET'])(UsuarioController.get_active_users)
# Show inactive
usuario_routes.route('/users/show/inactive', methods=['GET'])(UsuarioController.get_inactive_users)

# # Search
# usuario_routes.route('/users/search', methods=['POST'])(UsuarioController.refresh_token)


