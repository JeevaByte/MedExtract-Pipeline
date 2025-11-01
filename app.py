"""Main application for MedExtract-Pipeline."""
from flask import Flask, jsonify, request
from flask_login import login_user, logout_user, login_required, current_user
from config import Config
from models import db, User
from auth import login_manager, register_user, authenticate_user
from pipeline import MedExtractPipeline

app = Flask(__name__)
app.config.from_object(Config)

# Initialize extensions
db.init_app(app)
login_manager.init_app(app)
login_manager.login_view = 'login'

# Initialize pipeline
pipeline = MedExtractPipeline()


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint."""
    return jsonify({'status': 'healthy', 'service': 'MedExtract-Pipeline'})


@app.route('/register', methods=['POST'])
def register():
    """Register a new user."""
    data = request.get_json()
    
    if not data or not all(k in data for k in ('username', 'email', 'password')):
        return jsonify({'error': 'Missing required fields'}), 400
    
    user, message = register_user(
        data['username'],
        data['email'],
        data['password']
    )
    
    if user:
        return jsonify({'message': message, 'username': user.username}), 201
    else:
        return jsonify({'error': message}), 400


@app.route('/login', methods=['POST'])
def login():
    """Login user."""
    data = request.get_json()
    
    if not data or not all(k in data for k in ('username', 'password')):
        return jsonify({'error': 'Missing required fields'}), 400
    
    user, message = authenticate_user(data['username'], data['password'])
    
    if user:
        login_user(user)
        return jsonify({'message': message, 'username': user.username}), 200
    else:
        return jsonify({'error': message}), 401


@app.route('/logout', methods=['GET'])
@login_required
def logout():
    """Logout user."""
    username = current_user.username
    logout_user()
    return jsonify({'message': 'Logout successful', 'username': username}), 200


@app.route('/extract', methods=['POST'])
@login_required
def extract():
    """Extract medical data from text."""
    data = request.get_json()
    
    if not data or 'text' not in data:
        return jsonify({'error': 'Missing text field'}), 400
    
    result = pipeline.process(data['text'])
    result['user'] = current_user.username
    
    return jsonify(result), 200


@app.route('/user', methods=['GET'])
@login_required
def get_user():
    """Get current user information."""
    return jsonify({
        'username': current_user.username,
        'email': current_user.email
    }), 200


if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    app.run(debug=True, host='0.0.0.0', port=5000)
