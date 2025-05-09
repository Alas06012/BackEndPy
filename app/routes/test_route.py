from flask import Blueprint
from app.controllers.test_controller import TestController


test_routes = Blueprint('test_routes', __name__)


# Ruta para crear un nuevo test
test_routes.route('/newtest', methods=['POST'])(TestController.create_test)

# Ruta para crear un finalizar test
test_routes.route('/finish-test', methods=['POST'])(TestController.finish_test)

# Ruta para obtener la data de un test por id
test_routes.route('/test-data', methods=['POST'])(TestController.get_test_by_id)