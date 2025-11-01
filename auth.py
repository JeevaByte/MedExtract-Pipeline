"""Authentication module for MedExtract-Pipeline."""
from flask import jsonify, request
from flask_login import LoginManager, login_user, logout_user, login_required
from models import User, db

login_manager = LoginManager()


@login_manager.user_loader
def load_user(user_id):
    """Load user by ID."""
    return User.query.get(int(user_id))


def register_user(username, email, password):
    """Register a new user."""
    if User.query.filter_by(username=username).first():
        return None, "Username already exists"
    
    if User.query.filter_by(email=email).first():
        return None, "Email already exists"
    
    user = User(username=username, email=email)
    user.set_password(password)
    db.session.add(user)
    db.session.commit()
    
    return user, "User registered successfully"


def authenticate_user(username, password):
    """Authenticate user with username and password."""
    user = User.query.filter_by(username=username).first()
    
    if user and user.check_password(password):
        return user, "Login successful"
    
    return None, "Invalid username or password"
