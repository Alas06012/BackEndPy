from flask import Blueprint
from app.controllers.test_controller import TestController


test_route = Blueprint('test_route', __name__)


# Ruta para crear un nuevo test
test_route.route('/newtest', methods=['POST'])(TestController.create_test)

# Ruta para crear un finalizar test
test_route.route('/finish-test', methods=['POST'])(TestController.finish_test)