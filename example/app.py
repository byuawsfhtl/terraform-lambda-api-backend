from flask import Flask, request, jsonify

app = Flask(__name__)

# Sample data store
data_store = ["koala"]

# GET endpoint
@app.route('/example-path', methods=['GET'])
def get_data():
    return jsonify(data_store), 200

# POST endpoint
@app.route('/example-path', methods=['POST'])
def post_data():
    data = request.json
    data_store.append(data)
    return jsonify(data), 201

# DELETE endpoint
@app.route('/example-path', methods=['DELETE'])
def delete_data():
    data = request.json
    if data in data_store:
        data_store.remove(data)
        return jsonify({"message": "Data deleted"}), 200
    return jsonify({"message": "Data not found"}), 404
