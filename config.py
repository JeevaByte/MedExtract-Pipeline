"""Configuration settings for MedExtract-Pipeline."""
import os


class Config:
    """Base configuration."""
    
    SECRET_KEY = os.environ.get('SECRET_KEY') or 'dev-secret-key-change-in-production'
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL') or 'sqlite:///medextract.db'
    SQLALCHEMY_TRACK_MODIFICATIONS = False
