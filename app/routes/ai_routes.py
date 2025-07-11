# app/routes/questions_ai_routes.py
from flask import Blueprint
from app.controllers.title_controller import TitleController

questions_ai_routes = Blueprint('/ai/generate-quiz', __name__)

# Ruta para generar un nuevo título y preguntas con IA
questions_ai_routes.route('/ai/generate-quiz', methods=['POST'])(TitleController.generate_quiz_from_ai)

# Ruta para guardar el contenido generado por IA en la base de datos
questions_ai_routes.route('/ai/save-quiz', methods=['POST'])(TitleController.save_generated_quiz)