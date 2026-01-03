variable "code_path" {
  type        = string
  description = "Path of the code of the project, containing the pyproject file"
}

variable "artifact_repository_endpoint" {
  type        = string
  description = "Endpoint URL of the artifact repository"
}

variable "artifact_repository_domain_name" {
  type        = string
  description = "Domain name of the artifact repository"
}
