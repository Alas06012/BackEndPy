from flask import Blueprint
from app.controllers.test_comments_controller import TestComments


test_comments_routes = Blueprint('test_comments_routes', __name__)


# Ruta para agregar comentarios a un test por id
test_comments_routes.route('/test-comments', methods=['POST'])(TestComments.add_comment_to_test)

# Ruta para listar comentarios a un test por id
test_comments_routes.route('/test-comments-per-id', methods=['POST'])(TestComments.get_comments_by_test)

# Ruta para editar comentarios a un test por id
test_comments_routes.route('/test-comments', methods=['PUT'])(TestComments.edit_comment)