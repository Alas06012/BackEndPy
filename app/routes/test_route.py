from flask import Blueprint
from app.controllers.test_controller import TestController


test_routes = Blueprint('test_routes', __name__)


# Ruta para crear un nuevo test
test_routes.route('/newtest', methods=['POST'])(TestController.create_test)

# Ruta para crear un finalizar test
test_routes.route('/finish-test', methods=['POST'])(TestController.finish_test)

# Ruta para obtener la data de un test por id
test_routes.route('/test-data', methods=['POST'])(TestController.get_test_by_id)

# Ruta para agregar comentarios a un test por id
test_routes.route('/test-comments', methods=['POST'])(TestController.add_comment_to_test)

# Ruta para ver/filtrar todos los examenes
test_routes.route('/all-tests', methods=['POST'])(TestController.get_filtered_tests)