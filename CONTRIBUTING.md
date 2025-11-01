# Contributing to MedExtract-Pipeline

Thank you for your interest in contributing to MedExtract-Pipeline! This document provides guidelines for contributing to the project.

## Code of Conduct

This project adheres to a code of professional conduct. By participating, you are expected to uphold this code.

## How to Contribute

### Reporting Issues

- Use GitHub Issues to report bugs or suggest features
- Check existing issues before creating a new one
- Provide detailed information including:
  - Steps to reproduce (for bugs)
  - Expected vs actual behavior
  - System/environment details
  - Sample data (with PHI removed)

### Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Update documentation
7. Commit with clear messages (`git commit -m 'Add amazing feature'`)
8. Push to your fork (`git push origin feature/amazing-feature`)
9. Open a Pull Request

### Coding Standards

#### Python
- Follow PEP 8 style guide
- Use type hints where applicable
- Write docstrings for all functions and classes
- Maximum line length: 100 characters

#### Terraform
- Use consistent formatting (`terraform fmt`)
- Add comments for complex resources
- Use variables for all configurable values
- Follow naming conventions: `${project_name}-${resource_type}-${environment}`

#### Documentation
- Use Markdown for all documentation
- Keep README.md up to date
- Document all configuration options
- Include examples where helpful

### Testing

All contributions must include appropriate tests:

- Unit tests for individual functions
- Integration tests for component interactions
- Update test documentation

Run tests before submitting:
```bash
pytest tests/
terraform validate
```

### Security

- Never commit sensitive data (credentials, PHI, etc.)
- Use AWS Secrets Manager for secrets
- Follow OWASP security guidelines
- Report security vulnerabilities privately

### Healthcare Data

- Use only synthetic or de-identified data for testing
- Follow HIPAA and GDPR guidelines
- Document any PHI handling changes
- Get approval from maintainers for clinical logic changes

## Development Setup

### Prerequisites
- Python 3.11+
- Terraform 1.0+
- AWS CLI configured
- Git

### Local Setup
```bash
# Clone repository
git clone https://github.com/JeevaByte/MedExtract-Pipeline.git
cd MedExtract-Pipeline

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install development dependencies
pip install -r requirements-dev.txt

# Run tests
pytest
```

## Project Structure

```
MedExtract-Pipeline/
├── lambda/          # Lambda function code
├── terraform/       # Infrastructure as Code
├── sql/            # Database schemas
├── mapping/        # Ontology mappings
├── samples/        # Sample data
├── docs/           # Documentation
└── tests/          # Test suites
```

## Commit Messages

Use conventional commit format:
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `test:` Test additions or changes
- `refactor:` Code refactoring
- `chore:` Maintenance tasks

Example: `feat: add FHIR R4 export capability`

## Review Process

1. Automated CI/CD checks must pass
2. At least one maintainer approval required
3. Security scan must pass
4. Documentation must be updated
5. Tests must achieve 80%+ coverage

## Questions?

- Open a GitHub Discussion for general questions
- Tag maintainers for urgent issues
- Check existing documentation first

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to MedExtract-Pipeline! 🏥
