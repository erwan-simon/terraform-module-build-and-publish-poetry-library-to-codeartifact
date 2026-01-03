locals {
  poetry_version = regex("[0-9]+.[0-9]+.[0-9]+", regex("version[ ]*=[ ]*\"[0-9]+.[0-9]+.[0-9]+\"", file("${var.code_path}/pyproject.toml")))
}
