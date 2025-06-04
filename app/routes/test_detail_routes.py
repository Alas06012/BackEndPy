from flask import Blueprint
from app.controllers.test_detail_controller import TestDetailController


test_detail_routes = Blueprint('test_detail_routes', __name__)

#Ruta para mostrar preguntas y respuestas de los test
test_detail_routes.route('/test-details-with-answers', methods=['POST'])(TestDetailController.get_test_details_with_answers)