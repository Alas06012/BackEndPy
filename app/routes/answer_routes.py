from flask import Blueprint
from app.controllers.answer_controller import AnswersController


answer_routes = Blueprint('answer_routes', __name__)

# Ruta para crear answers
answer_routes.route('/answer', methods=['POST'])(AnswersController.create_answers)

# Ruta para crear answers en bulk
answer_routes.route('/bulk-answers', methods=['POST'])(AnswersController.create_bulk_answers)

# Ruta para crear editar answers
answer_routes.route('/answer', methods=['PUT'])(AnswersController.edit_answer)

# Ruta para crear eliminar answers
answer_routes.route('/answer', methods=['DELETE'])(AnswersController.deactivate_answer)

# Ruta para crear mostrar answers por pregunta
answer_routes.route('/answers-per-question', methods=['GET'])(AnswersController.get_filtered_answers)

# Ruta para crear mostrar inactive answers
#answer_routes.route('/inactive-answers', methods=['GET'])(AnswersController.get_inactive_answers)

# Ruta para crear mostrar active answers
#answer_routes.route('/active-answers', methods=['GET'])(AnswersController.get_active_questions)







