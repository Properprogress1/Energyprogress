# Contributing to Ropa Citi

Thank you for your interest in contributing to Ropa Citi! This document provides guidelines and instructions for contributing to the project.

## Code of Conduct

- Be respectful and inclusive
- Focus on what is best for the community
- Show empathy towards other community members

## Development Workflow

### 1. Setup Development Environment

Follow the instructions in the main README.md to set up your development environment.

### 2. Create a Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/your-bug-fix
```

### 3. Make Your Changes

- Follow the existing code style and conventions
- Add tests for new features
- Update documentation as needed
- Ensure all tests pass

### 4. Commit Your Changes

```bash
git add .
git commit -m "feat: add your feature description"
# or
git commit -m "fix: fix your bug description"
```

### 5. Push to Your Fork

```bash
git push origin feature/your-feature-name
```

### 6. Create a Pull Request

- Go to the repository on GitHub
- Click "New Pull Request"
- Provide a clear description of your changes
- Link any related issues

## Coding Standards

### Smart Contracts

- Use Solidity 0.8.20 or higher
- Follow the Solidity style guide
- Add NatSpec comments for all public functions
- Use OpenZeppelin contracts where appropriate
- Write comprehensive tests
- Follow the Checks-Effects-Interactions pattern

### Frontend

- Use TypeScript for all new code
- Follow React and Next.js best practices
- Use Tailwind CSS for styling
- Write meaningful component names
- Add comments for complex logic
- Ensure mobile responsiveness

### General

- Write clear, descriptive commit messages
- Keep functions focused and small
- Avoid code duplication
- Use meaningful variable and function names
- Add error handling where appropriate

## Testing

### Smart Contract Tests

- Unit tests for all public functions
- Fuzz tests for edge cases
- Invariant tests for protocol properties
- Negative tests for security properties

### Frontend Tests

- Component tests for React components
- Integration tests for contract interactions
- End-to-end tests for critical user flows

## Documentation

- Update README.md for user-facing changes
- Add inline comments for complex logic
- Update API documentation for contract changes
- Add examples for new features

## Pull Request Guidelines

### PR Title Format

- `feat:` for new features
- `fix:` for bug fixes
- `docs:` for documentation changes
- `test:` for test changes
- `refactor:` for code refactoring

### PR Description

Include:
- What changes were made and why
- How the changes were tested
- Any breaking changes
- Screenshots for UI changes
- Links to related issues

### Review Process

- All PRs must be reviewed by at least one maintainer
- All tests must pass
- Code must follow project standards
- Documentation must be updated

## Issue Reporting

### Bug Reports

- Use the issue template
- Provide steps to reproduce
- Include environment details
- Add relevant logs or screenshots

### Feature Requests

- Describe the feature clearly
- Explain the use case
- Discuss potential implementation
- Consider if it fits the project scope

## Release Process

Releases are versioned using Semantic Versioning (SemVer):
- MAJOR version for incompatible API changes
- MINOR version for backwards-compatible functionality
- PATCH version for backwards-compatible bug fixes

## Questions?

Feel free to open an issue for clarification on any of these guidelines.

Happy contributing! 🚀