from flask import Blueprint
from app.controllers.test_comments_controller import TestComments


test_comments_routes = Blueprint('test_comments_routes', __name__)


# Ruta para agregar comentarios a un test por id
test_comments_routes.route('/test-comments', methods=['POST'])(TestComments.add_comment_to_test)

# Ruta para listar comentarios a un test por id
test_comments_routes.route('/test-comments-per-id', methods=['POST'])(TestComments.get_comments_by_test)

# Ruta para editar comentarios a un test por id
test_comments_routes.route('/test-comments', methods=['PUT'])(TestComments.edit_comment)

# Ruta para consultar detalle de preguntas
test_comments_routes.route('/generate-ai-comment', methods=['POST'])(TestComments.generate_ai_comment)

# Ruta para consultar detalle de preguntas
test_comments_routes.route('/check-ai-requests', methods=['GET'])(TestComments.check_ai_requests)