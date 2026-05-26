output "repository_endpoint" {
  description = "PyPI endpoint of the CodeArtifact repository the module published to"
  value       = data.aws_codeartifact_repository_endpoint.main.repository_endpoint
}

output "published_package" {
  description = "Name and version of the package successfully published and pip-installed by the verify step"
  value       = "${local.package_name}==${local.expected_version}"
}
