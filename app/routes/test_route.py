from flask import Blueprint
from app.controllers.test_controller import TestController


test_route = Blueprint('test_route', __name__)

#   AUTENTICACIÓN
#   ---------------------------
# 
# Ruta para registrar un usuario
test_route.route('/newtest', methods=['POST'])(TestController.create_test)