# terraform-module-build-and-publish-poetry-library-to-codeartifact

* [I. Project Overview](#i-project-overview)
* [II. Architecture / Design](#ii-architecture--design)
* [III. Prerequisites](#iii-prerequisites)
* [IV. Installation / Setup](#iv-installation--setup)
* [V. Usage](#v-usage)
* [VI. Infrastructure](#vi-infrastructure)
* [VII. Configuration](#vii-configuration)
* [VIII. Project Structure](#viii-project-structure)
* [IX. Limitations / Assumptions](#ix-limitations--assumptions)

## I. Project Overview

This is a Terraform module that automates the process of building and publishing Python libraries managed by Poetry to AWS CodeArtifact. The module is designed to be reusable and can be integrated into Terraform configurations to handle the complete lifecycle of Python package publication.

The module is particularly useful for organizations that:
- Manage Python libraries using Poetry for dependency management and packaging
- Use AWS CodeArtifact as their private Python package repository
- Want to automate the build and publish process as part of their infrastructure-as-code workflow

## II. Architecture / Design

The module follows a simple but effective architecture:

1. **Version Detection**: Extracts the version number from the `pyproject.toml` file using regex pattern matching
2. **Trigger Mechanism**: Uses a Terraform `null_resource` with a trigger based on the detected Poetry version to ensure republication only when the version changes
3. **Build and Publish Script**: Executes a bash script that:
   - Authenticates with AWS CodeArtifact using AWS STS credentials
   - Configures Poetry with the CodeArtifact repository credentials
   - Builds and publishes the library using Poetry's built-in commands

The module is stateless and relies on Terraform's change detection mechanism to determine when to rebuild and republish the library.

### Key Components

- **Terraform Resources**: Define the automation workflow using `null_resource` with local-exec provisioner
- **Shell Script**: Handles the actual build and publish operations with proper authentication
- **Version Tracking**: Automatically detects version changes to trigger rebuilds

## III. Prerequisites

### Required Tools

- **Terraform**: Version compatible with `null_resource` and `local-exec` provisioner
- **AWS CLI**: Configured with appropriate credentials and permissions
- **Poetry**: Python dependency management and packaging tool
- **Bash**: Shell environment for executing the build script

### AWS Permissions

The AWS credentials used must have permissions to:
- Call `sts:GetCallerIdentity` (to retrieve the AWS account ID)
- Call `codeartifact:GetAuthorizationToken` (to authenticate with CodeArtifact)
- Publish packages to the specified CodeArtifact repository

### Python Project Requirements

The target Python project must:
- Be managed by Poetry
- Have a valid `pyproject.toml` file with a version field in the format `version = "x.y.z"`
- Be ready for publication (all dependencies resolved, valid package structure)

## IV. Installation / Setup

### Module Integration

To use this module in your Terraform configuration, reference it as a module:

```hcl
module "publish_library" {
  source = "path/to/terraform-module-build-and-publish-poetry-library-to-codeartifact/iac"

  code_path                         = "/path/to/your/python/project"
  artifact_repository_domain_name   = "your-codeartifact-domain"
  artifact_repository_endpoint      = "https://your-codeartifact-domain-123456789012.d.codeartifact.region.amazonaws.com/pypi/your-repo/"
}
```

### Local Development Setup

For local development of this module:

1. Clone the repository
2. Ensure AWS credentials are configured (see organizational context for credential management)
3. Ensure Poetry is installed on your system
4. Navigate to the `iac` directory for Terraform operations

## V. Usage

### Basic Usage

After integrating the module into your Terraform configuration:

```bash
# Initialize Terraform
terraform init

# Plan the changes
terraform plan

# Apply to build and publish the library
terraform apply
```

### Version Updates

The module automatically detects version changes in the `pyproject.toml` file. When you update the version:

1. Update the version field in your Python project's `pyproject.toml`
2. Run `terraform plan` - Terraform will detect the version change
3. Run `terraform apply` - The module will rebuild and republish with the new version

### Manual Trigger

If you need to force a republish without a version change, you can taint the resource:

```bash
terraform taint module.publish_library.null_resource.build_and_publish_code
terraform apply
```

## VI. Infrastructure

### Terraform Resources

#### `null_resource.build_and_publish_code`

The primary resource that orchestrates the build and publish process.

- **Provisioner**: Uses `local-exec` to execute the bash script
- **Triggers**: Configured to re-execute when the Poetry version changes
- **Working Directory**: Executes from the module's directory

#### Script: `build_and_publish_code.sh`

The bash script performs the following operations:

1. **Authentication**: Retrieves AWS account ID and obtains a CodeArtifact authorization token
2. **Poetry Configuration**: Configures Poetry with the target repository and credentials
3. **Build and Publish**: Executes `poetry publish --build --no-interaction -r target`
4. **Error Handling**: Exits with error code if publication fails

### Deployment Workflow

In GitLab CI (as configured in `.gitlab-ci.yml`):
- The module is versioned using semantic-release
- Releases are automated based on conventional commits
- The module is mirrored to GitHub (read-only)

## VII. Configuration

### Input Variables

| Variable | Type | Description | Required |
|----------|------|-------------|----------|
| `code_path` | string | Path to the Python project directory containing `pyproject.toml` | Yes |
| `artifact_repository_endpoint` | string | Full endpoint URL of the CodeArtifact repository | Yes |
| `artifact_repository_domain_name` | string | Name of the CodeArtifact domain | Yes |

### Output Variables

| Output | Description |
|--------|-------------|
| `code_path` | Returns the path to the code that was published |

### Environment Variables

The bash script relies on AWS CLI default credential resolution. Ensure the following are configured:

- `AWS_ACCESS_KEY_ID` (if not using instance profiles/roles)
- `AWS_SECRET_ACCESS_KEY` (if not using instance profiles/roles)
- `AWS_REGION` (defaults to `eu-west-1` per organizational convention)

### Poetry Configuration

The module dynamically configures Poetry with:
- Repository name: `target`
- Authentication method: `http-basic` with AWS credentials
- Repository URL: Provided via `artifact_repository_endpoint` variable

## VIII. Project Structure

```
.
├── .gitlab-ci.yml          # GitLab CI/CD pipeline configuration
├── .releaserc.json         # Semantic-release configuration
├── .gitignore              # Git ignore patterns
├── iac/                    # Terraform module directory
│   ├── variables.tf        # Input variable definitions
│   ├── locals.tf           # Local value for version extraction
│   ├── build_and_publish_code.tf    # Main resource definition
│   ├── build_and_publish_code.sh    # Build and publish script
│   └── outputs.tf          # Output variable definitions
└── tests/                  # End-to-end functional tests
    └── simple/             # Publishes a minimal Poetry lib and pip-installs it back to assert it is consumable
```

### A. Terraform Module (`iac/`)

Contains all Terraform configuration files that define the module's behavior:

- **variables.tf**: Defines the required input parameters for the module
- **locals.tf**: Extracts and parses the Poetry version from `pyproject.toml` using regex
- **build_and_publish_code.tf**: Defines the `null_resource` that triggers the build and publish process
- **outputs.tf**: Exports the code path for reference by parent modules
- **build_and_publish_code.sh**: Bash script that handles AWS authentication, Poetry configuration, and package publication

### B. CI/CD Configuration

- **.gitlab-ci.yml**: Defines the GitLab CI/CD pipeline with stages for initialization, security scanning, functional tests, release automation, and GitHub mirroring
- **.releaserc.json**: Configures semantic-release for automated versioning based on conventional commits

### C. Functional Tests (`tests/`)

End-to-end tests that exercise the module against real AWS resources. The `tests/simple/` test provisions a CodeArtifact domain + repositories, publishes a minimal Poetry library through the module, then `pip install`s it back and runs its entrypoint to assert the publication is actually consumable (including transitive dependency resolution through an upstream PyPI connection). Each test is a self-contained Terraform stack; see `tests/simple/README.md` for usage. The `test_simple` job in `.gitlab-ci.yml` runs this stack and tears it down in `after_script`.

## IX. Limitations / Assumptions

### Assumptions

1. **Poetry Version Format**: The module assumes the version in `pyproject.toml` follows semantic versioning (`x.y.z` format)
2. **AWS Authentication**: Assumes AWS credentials are available via standard AWS CLI credential resolution
3. **Poetry Installation**: Assumes Poetry is installed and available in the PATH where Terraform is executed
4. **Bash Environment**: Requires a Unix-like environment with bash shell
5. **Regional Deployment**: Per organizational convention, assumes AWS resources are in `eu-west-1` unless explicitly configured otherwise

### Limitations

1. **Single Repository**: The module publishes to a single CodeArtifact repository per invocation
2. **No Dependency Installation**: Does not verify or install Poetry dependencies before building
3. **Error Handling**: Limited error handling in the bash script; failures will cause Terraform to fail
4. **Version Change Detection Only**: The trigger only detects version changes; other changes to the project won't trigger a republish unless manually tainted
5. **No Build Artifact Caching**: Each execution rebuilds from scratch; no caching mechanism
6. **Local Execution**: The `local-exec` provisioner requires the build environment to be configured on the machine running Terraform
7. **No Rollback**: Once published, there's no automated rollback mechanism for failed deployments

### Known Constraints

- The regex pattern for version extraction is rigid and may not work with non-standard version formats
- The module does not support publishing to multiple repositories simultaneously
- The bash script assumes the CodeArtifact domain is in the same AWS account as the credentials being used