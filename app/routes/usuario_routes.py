
from flask import Blueprint
from app.controllers.usuario_controller import UsuarioController


usuario_routes = Blueprint('usuario_routes', __name__)

# Ruta para registrar un usuario
usuario_routes.route('/register', methods=['POST'])(UsuarioController.register_user)

# Ruta para iniciar sesión (login)
usuario_routes.route('/login', methods=['POST'])((UsuarioController.login_user))

# Ruta protegida para obtener información del usuario actual
usuario_routes.route('/me', methods=['GET'])(UsuarioController.get_user_info)

