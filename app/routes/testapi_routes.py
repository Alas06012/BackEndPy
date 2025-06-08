from flask import Blueprint
from app.controllers.testapi_controller import TestApiController


testapi_route = Blueprint('testapi_route', __name__)


# Ruta para crear un nuevo test
testapi_route.route('/testapi', methods=['POST'])(TestApiController.test_api)