terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  domain_name      = "${var.name_prefix}-domain"
  upstream_repo    = "${var.name_prefix}-pypi-store"
  main_repo        = "${var.name_prefix}-main"
  package_name     = "tfmodule-codeartifact-test"
  expected_version = "0.1.0"
  expected_output  = "hello from terraform-test using requests"
}

resource "aws_codeartifact_domain" "test" {
  domain = local.domain_name
}

resource "aws_codeartifact_repository" "pypi_store" {
  repository = local.upstream_repo
  domain     = aws_codeartifact_domain.test.domain

  external_connections {
    external_connection_name = "public:pypi"
  }
}

resource "aws_codeartifact_repository" "main" {
  repository = local.main_repo
  domain     = aws_codeartifact_domain.test.domain

  upstream {
    repository_name = aws_codeartifact_repository.pypi_store.repository
  }
}

data "aws_codeartifact_repository_endpoint" "main" {
  domain     = aws_codeartifact_domain.test.domain
  repository = aws_codeartifact_repository.main.repository
  format     = "pypi"
}

module "publish" {
  source = "../../iac"

  code_path                       = abspath("${path.root}/lib")
  artifact_repository_domain_name = aws_codeartifact_domain.test.domain
  artifact_repository_endpoint    = data.aws_codeartifact_repository_endpoint.main.repository_endpoint
}

resource "null_resource" "verify" {
  triggers = {
    package_version = local.expected_version
  }

  provisioner "local-exec" {
    working_dir = path.module
    command = join(" ", [
      "/bin/bash",
      "verify.sh",
      aws_codeartifact_domain.test.domain,
      aws_codeartifact_repository.main.repository,
      var.aws_region,
      local.package_name,
      local.expected_version,
      "'${local.expected_output}'",
    ])
  }

  depends_on = [module.publish]
}
