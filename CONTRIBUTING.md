# Contributing to Scenic Walk

Thank you for your interest in contributing to Scenic Walk! This document provides guidelines for contributing to the project.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/scenic-walk.git`
3. Create a branch: `git checkout -b feature/your-feature-name`
4. Make your changes
5. Test your changes locally
6. Commit with a descriptive message
7. Push to your fork: `git push origin feature/your-feature-name`
8. Open a Pull Request

## Development Setup

```bash
# Install dependencies
npm install

# Copy environment template
cp .env.example .env

# Add your Firebase and Google Maps credentials to .env

# Start development server
npm run dev
```

## Code Style

- Use TypeScript for all new code
- Follow existing code patterns and naming conventions
- Use functional components with hooks
- Keep components focused and single-purpose
- Add TypeScript types for all props and state

## Commit Messages

Use clear, descriptive commit messages:

```
feat: add support for multiple organizers
fix: resolve location accuracy display issue
docs: update setup instructions
refactor: simplify route drawing logic
```

## Pull Request Guidelines

1. **One feature per PR** - Keep PRs focused on a single change
2. **Test your changes** - Ensure the app works correctly
3. **Update documentation** - If your change affects usage
4. **Describe your changes** - Explain what and why in the PR description

## Reporting Bugs

When reporting bugs, please include:

1. Steps to reproduce
2. Expected behavior
3. Actual behavior
4. Browser and device information
5. Screenshots if applicable

## Feature Requests

Feature requests are welcome! Please describe:

1. The problem you're trying to solve
2. Your proposed solution
3. Alternative solutions you've considered

## Code of Conduct

- Be respectful and inclusive
- Welcome newcomers
- Focus on constructive feedback
- Respect different viewpoints

## License

By contributing, you agree that your contributions will be licensed under the AGPL-3.0 License.

## Questions?

Open an issue or reach out to the maintainers.
