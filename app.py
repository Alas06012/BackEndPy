from flask import Flask, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)  # Habilitar CORS para permitir peticiones desde el frontend

@app.route('/api/consulta', methods=['GET'])
def consulta():
    return jsonify({"mensaje": "CONSULTA A API REALIZADA CORRECTAMENTE"})

if __name__ == '__main__':
    app.run(debug=False, port=5000)
