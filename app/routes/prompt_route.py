from flask import Blueprint
from app.controllers.prompt_controller import PromptController


prompt_routes = Blueprint('prompt_routes', __name__)

#Ruta para crear prompt nuevo
prompt_routes.route('/prompt', methods=['POST'])(PromptController.create_prompt)

#Ruta para editar prompt nuevo
prompt_routes.route('/prompt', methods=['PUT'])(PromptController.edit_prompt)

#Ruta para mostrar prompts
prompt_routes.route('/prompts', methods=['GET'])(PromptController.get_filtered_prompts)

#Ruta para activar prompts
prompt_routes.route('/activate-prompts', methods=['POST'])(PromptController.activate_prompt)