resource "terraform_data" "build_and_publish_code" {
  triggers_replace = [local.poetry_version]

  provisioner "local-exec" {
    working_dir = path.module
    command = join(" ", [
      "/bin/bash",
      "build_and_publish_code.sh",
      var.code_path,
      var.artifact_repository_domain_name,
      var.artifact_repository_endpoint
    ])
  }
}
