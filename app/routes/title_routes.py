from flask import Blueprint
from app.controllers.title_controller import TitleController


title_routes = Blueprint('title_routes', __name__)


# Ruta para registrar un title
title_routes.route('/story', methods=['POST'])(TitleController.create_story)

# Ruta para editar titles
title_routes.route('/story', methods=['PUT'])(TitleController.edit_title)

# Ruta para eliminar titles
title_routes.route('/story', methods=['DELETE'])(TitleController.deactivate_title)

# Ruta para listar titles filtrados
title_routes.route('/stories', methods=['POST'])(TitleController.get_filtered_titles)

# Ruta para listar titles activos
#title_routes.route('/active-stories', methods=['GET'])(TitleController.get_active_titles)

# Ruta para listar titles inactivos
#title_routes.route('/inactive-stories', methods=['GET'])(TitleController.get_inactive_titles)