resource "null_resource" "build_and_publish_code" {
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
  triggers = {
    poetry_version_change = local.poetry_version
  }
}
