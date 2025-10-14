# Claude Code Configuration

## Language Preference
**Always communicate in Japanese (日本語) for this project.**

## Project Overview
This is a Kubernetes Helm chart for deploying Dify on Google Cloud Platform using Google Cloud Native services.

## Development Commands
```bash
# Helm commands
helm template . > output.yaml                    # Generate templates
helm lint .                                      # Lint chart
helm dependency update                           # Update dependencies

# Kubernetes commands
kubectl apply -f .                               # Apply resources
kubectl get pods -n dify                        # Check pod status
kubectl logs -f deployment/dify-api -n dify     # View API logs
kubectl logs -f deployment/dify-web -n dify     # View web logs
```

## Code Style Guidelines
- Use 2 spaces for YAML indentation
- Follow Kubernetes naming conventions (lowercase with hyphens)
- Use descriptive resource names with consistent prefixes
- Include appropriate labels and annotations
- Follow Helm best practices for templating

## File Structure
- `templates/` - Kubernetes resource templates
- `charts/` - Chart dependencies
- `values.yaml` - Default configuration values
- `Chart.yaml` - Chart metadata

## Testing
```bash
# Validate YAML syntax
yamllint templates/
helm template . | kubeval

# Test deployment
helm install dify-test . --dry-run --debug
```

## Important Notes
- This chart uses Google Cloud Native services
- Ensure proper RBAC permissions are configured
- Monitor resource usage with HPA configurations
- Use external secrets for sensitive data