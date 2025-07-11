from flask import Blueprint
from app.controllers.Level_Controller  import LevelController

level_routes = Blueprint('level_routes', __name__)

# Crear un nuevo nivel
level_routes.route('/level', methods=['POST'])(LevelController.create_level)

# Editar un nivel existente
level_routes.route('/level', methods=['PUT'])(LevelController.update_level)

# Eliminar (borrar) un nivel
level_routes.route('/level', methods=['DELETE'])(LevelController.delete_level)

# Obtener todos los niveles sin filtros (opcional)
level_routes.route('/levels', methods=['POST'])(LevelController.get_all_mcer_levels)
#level_routes.route('/levels', methods=['POST'])(LevelController.get_levels_paginated)

# Obtener niveles con paginación y búsqueda
level_routes.route('/levels/paginated', methods=['POST'])(LevelController.get_levels_paginated)
