from flask import Blueprint
from app.controllers.studymaterial_controller import StudyMaterialController

studymaterial_routes = Blueprint('studymaterial_routes', __name__)

#   ADMINISTRACIÓN DE MATERIALES
#   ---------------------------
#   Se necesita rol de admin

# Crear material
studymaterial_routes.route('/materials/create', methods=['POST'])(StudyMaterialController.create_material)
# Obtener todos los materiales
studymaterial_routes.route('/materials/all', methods=['GET'])(StudyMaterialController.get_all_materials)
# Obtener un material específico
studymaterial_routes.route('/materials/single', methods=['POST'])(StudyMaterialController.get_material)
# Actualizar material
studymaterial_routes.route('/materials/update', methods=['PUT'])(StudyMaterialController.update_material)
# Eliminar material
studymaterial_routes.route('/materials/delete', methods=['DELETE'])(StudyMaterialController.delete_material)
# Búsqueda filtrada y paginada
studymaterial_routes.route('/materials/filter', methods=['POST'])(StudyMaterialController.get_filtered_materials)