# Contributing to O-RAN FL xApp

Thank you for your interest in contributing to the O-RAN Federated Learning xApp! This document provides guidelines for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Reporting Issues](#reporting-issues)

## Code of Conduct

This project follows the [O-RAN Software Community Code of Conduct](https://www.o-ran.org/code-of-conduct). By participating, you are expected to uphold this code.

## Getting Started

### Prerequisites

- Python 3.11+
- Docker 20.10+
- Kubernetes 1.24+ (for testing)
- Git

### Development Setup

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/oran-ric-fl-xapp.git
   cd oran-ric-fl-xapp
   ```

3. Create a virtual environment:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```

4. Install development dependencies:
   ```bash
   pip install -r requirements.txt
   pip install pytest pylint mypy black
   ```

5. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Workflow

### 1. Planning

- Check existing issues for similar work
- Create an issue describing your proposed changes
- Discuss the approach with maintainers
- Wait for approval before starting major work

### 2. Implementation

- Follow the [Coding Standards](#coding-standards)
- Write tests for new features
- Update documentation as needed
- Keep commits focused and atomic
- Write clear commit messages

### 3. Testing

- Run unit tests: `pytest tests/unit/`
- Run integration tests: `pytest tests/integration/`
- Test locally with Docker: `./scripts/build.sh && ./scripts/deploy.sh`
- Verify GPU support (if applicable)
- Check code quality: `pylint src/ && mypy src/`

### 4. Submitting

- Push to your fork
- Create a pull request
- Address review feedback
- Ensure CI passes

## Coding Standards

### Python Style

Follow [PEP 8](https://www.python.org/dev/peps/pep-0008/) with these specifics:

- **Line length**: 100 characters
- **Indentation**: 4 spaces (no tabs)
- **Imports**: Group by standard library, third-party, local
- **Type hints**: Required for all functions
- **Docstrings**: Required for all public functions and classes

### Example

```python
# Standard library
from typing import Dict, List, Optional

# Third-party
import numpy as np
from ricxappframe.xapp_frame import RMRXapp

# Local
from src.models import FLModel


def aggregate_models(
    models: List[FLModel],
    weights: Optional[List[float]] = None
) -> FLModel:
    """
    Aggregate multiple FL models using weighted averaging.

    Args:
        models: List of FL models to aggregate
        weights: Optional weights for each model (defaults to equal weights)

    Returns:
        Aggregated FL model

    Raises:
        ValueError: If models list is empty or weights don't match
    """
    if not models:
        raise ValueError("Models list cannot be empty")

    # Implementation...
    return aggregated_model
```

### Code Quality Tools

- **Linting**: `pylint src/`
- **Type checking**: `mypy src/`
- **Formatting**: `black src/`
- **Import sorting**: `isort src/`

Run all checks:
```bash
pylint src/ && mypy src/ && black --check src/ && isort --check src/
```

## Testing

### Test Structure

```
tests/
├── unit/           # Unit tests (fast, isolated)
├── integration/    # Integration tests (with dependencies)
└── e2e/           # End-to-end tests (full deployment)
```

### Writing Tests

- Use `pytest` framework
- One test file per module
- Name tests descriptively: `test_<function>_<scenario>`
- Use fixtures for common setup
- Mock external dependencies in unit tests

### Example Test

```python
import pytest
from src.federated_learning import FederatedLearning


@pytest.fixture
def fl_config():
    """Fixture providing test FL configuration."""
    return {
        "min_clients": 3,
        "max_clients": 10,
        "rounds": 100,
        "aggregation_method": "fedavg"
    }


def test_fl_initialization_success(fl_config):
    """Test successful FL initialization with valid config."""
    fl = FederatedLearning(config=fl_config)
    assert fl.min_clients == 3
    assert fl.max_clients == 10


def test_fl_initialization_invalid_clients(fl_config):
    """Test FL initialization fails with invalid client count."""
    fl_config["min_clients"] = -1
    with pytest.raises(ValueError, match="min_clients must be positive"):
        FederatedLearning(config=fl_config)
```

### Running Tests

```bash
# Unit tests only
pytest tests/unit/ -v

# With coverage
pytest tests/ --cov=src --cov-report=html

# Specific test
pytest tests/unit/test_aggregation.py::test_fedavg_basic -v

# E2E tests (requires running cluster)
./scripts/test.sh e2e
```

## Submitting Changes

### Pull Request Process

1. **Update Documentation**
   - Update README.md if adding features
   - Add docstrings to new functions
   - Update API documentation if needed

2. **Create Pull Request**
   - Use a clear title: `[Feature/Fix/Docs] Description`
   - Fill out the PR template completely
   - Link related issues
   - Add screenshots for UI changes

3. **PR Template**
   ```markdown
   ## Description
   Brief description of changes

   ## Type of Change
   - [ ] Bug fix
   - [ ] New feature
   - [ ] Breaking change
   - [ ] Documentation update

   ## Testing
   - [ ] Unit tests pass
   - [ ] Integration tests pass
   - [ ] E2E tests pass
   - [ ] Tested locally

   ## Checklist
   - [ ] Code follows style guidelines
   - [ ] Self-reviewed code
   - [ ] Commented complex code
   - [ ] Updated documentation
   - [ ] No new warnings
   - [ ] Added tests
   ```

4. **Review Process**
   - Maintainers review within 3-5 business days
   - Address feedback promptly
   - Keep PR scope focused
   - Squash commits before merge

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Formatting
- `refactor`: Code restructuring
- `test`: Adding tests
- `chore`: Maintenance

**Examples:**
```
feat(aggregation): add FedOpt algorithm

Implement FedOpt (Federated Optimization) aggregation algorithm
with adaptive learning rate and momentum support.

Closes #123
```

```
fix(gpu): handle CUDA out of memory error

Add proper error handling when GPU memory is exhausted,
falling back to CPU mode gracefully.

Fixes #456
```

## Reporting Issues

### Bug Reports

Use the bug report template:

```markdown
**Describe the bug**
Clear description of the bug

**To Reproduce**
Steps to reproduce:
1. Deploy with command '...'
2. Send request to '...'
3. See error

**Expected behavior**
What should happen

**Environment:**
- OS: [e.g., Ubuntu 22.04]
- Kubernetes: [e.g., v1.28]
- Python: [e.g., 3.11]
- GPU: [e.g., NVIDIA T4, CUDA 11.8]

**Logs**
```
Paste relevant logs
```

**Additional context**
Any other relevant information
```

### Feature Requests

Use the feature request template:

```markdown
**Is your feature request related to a problem?**
Description of the problem

**Describe the solution**
Proposed solution

**Describe alternatives**
Alternative approaches considered

**Additional context**
Any mockups, diagrams, or examples
```

## Project Structure

```
oran-ric-fl-xapp/
├── src/                    # Source code
├── config/                 # Configuration files
├── deploy/                 # Deployment manifests
│   ├── kubernetes/         # Kubernetes YAML
│   └── helm/              # Helm charts
├── tests/                  # Test files
├── docs/                   # Documentation
├── scripts/                # Utility scripts
├── Dockerfile              # CPU Dockerfile
├── Dockerfile.gpu          # GPU Dockerfile
└── requirements.txt        # Python dependencies
```

## Communication

- **Issues**: For bugs and feature requests
- **Discussions**: For questions and ideas
- **Email**: ric-dev@lists.o-ran-sc.org
- **Slack**: O-RAN SC Workspace (get invite from website)

## Recognition

Contributors will be recognized in:
- CONTRIBUTORS.md file
- Release notes
- Project documentation

Thank you for contributing to O-RAN FL xApp!
