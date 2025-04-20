from flask import Blueprint
from app.controllers.question_controller import QuestionsController


question_routes = Blueprint('question_routes', __name__)

# Ruta para crear questions
question_routes.route('/question', methods=['POST'])(QuestionsController.create_question_with_answers)

# Ruta para crear bulk de questions
question_routes.route('/bulk-questions', methods=['POST'])(QuestionsController.create_questions_bulk)

# Ruta para eliminar questions
question_routes.route('/question', methods=['DELETE'])(QuestionsController.inactivate_question)

# Ruta para editar questions
question_routes.route('/question', methods=['PUT'])(QuestionsController.edit_question)

# Ruta para listar questions activos
question_routes.route('/active-questions', methods=['GET'])(QuestionsController.get_active_questions)

# Ruta para listar questions inactivos
question_routes.route('/inactive-questions', methods=['GET'])(QuestionsController.get_inactive_questions)

# Ruta para listar questions por title
question_routes.route('/questions-per-title', methods=['GET'])(QuestionsController.get_questions_per_title)





