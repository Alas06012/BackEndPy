from flask import Blueprint
from app.controllers.Section_controller import SectionController

section_routes = Blueprint('section_routes', __name__)

# Crear una nueva sección
section_routes.route('/section', methods=['POST'])(SectionController.create_section)

# Editar una sección existente
section_routes.route('/section', methods=['PUT'])(SectionController.update_section)

# Eliminar (borrar) una sección
section_routes.route('/section', methods=['DELETE'])(SectionController.delete_section)

# Obtener todas las secciones sin filtros
section_routes.route('/sections', methods=['POST'])(SectionController.get_all_sections)

# Obtener secciones con paginación y búsqueda
section_routes.route('/sections/paginated', methods=['POST'])(SectionController.get_sections_paginated)
