# MedExtract-Pipeline

A Python-based medical data extraction pipeline with user authentication.

## Features

- User authentication system with login/logout functionality
- Medical text data extraction pipeline
- Secure user management
- RESTful API endpoints

## Installation

1. Clone the repository:
```bash
git clone https://github.com/JeevaByte/MedExtract-Pipeline.git
cd MedExtract-Pipeline
```

2. Create a virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

3. Install dependencies:
```bash
pip install -r requirements.txt
```

4. Initialize the database:
```bash
python -c "from app import db, app; app.app_context().push(); db.create_all()"
```

## Usage

1. Start the application:
```bash
python app.py
```

2. Access the application at `http://localhost:5000`

3. Register a new user or login with existing credentials

4. Use the pipeline to extract medical data from text

## API Endpoints

- `POST /register` - Register a new user
- `POST /login` - Login with credentials
- `GET /logout` - Logout current user
- `POST /extract` - Extract medical data from text (requires authentication)
- `GET /health` - Check application health

## Project Structure

```
MedExtract-Pipeline/
├── app.py                 # Main application file
├── auth.py               # Authentication module
├── pipeline.py           # Medical data extraction pipeline
├── models.py             # Database models
├── config.py             # Configuration settings
├── requirements.txt      # Python dependencies
├── tests/               # Test suite
│   ├── test_auth.py
│   └── test_pipeline.py
└── README.md
```

## Running Tests

```bash
pytest tests/
```

## Security Notes

- Passwords are hashed using Werkzeug's security functions
- User sessions are managed securely with Flask-Login
- Authentication is required for all extraction endpoints

## License

MIT License