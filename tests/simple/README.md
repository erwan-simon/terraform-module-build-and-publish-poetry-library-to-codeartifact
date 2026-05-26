# tests/simple

End-to-end functional test for the module. Provisions a CodeArtifact domain + repository, publishes a minimal Poetry library through the module, then `pip install`s that library back from CodeArtifact and runs it to assert the publication is actually consumable.

## What it does

1. Creates an `aws_codeartifact_domain` and two `aws_codeartifact_repository` resources: a `pypi-store` upstream with an external connection to public PyPI (so transitive deps resolve), and a `main` repo wired to that upstream.
2. Calls the module at `../../iac` with `code_path` pointing to `./lib` (a minimal Poetry project depending on `requests`). The module publishes version `0.1.0` to the `main` repo.
3. Runs `verify.sh` via a `terraform_data` resource. The script creates a venv, logs pip into the CodeArtifact repo, `pip install`s `tfmodule-codeartifact-test==0.1.0`, asserts the transitive `requests` dependency was pulled, then runs the lib's entrypoint and checks the output.

If any step fails — publish, install, transitive dep missing, wrong output — `terraform apply` fails.

## Prerequisites

- Terraform >= 1.5
- Python 3.9+ with `venv` available on `python3`
- Poetry installed and on PATH (the module's script invokes `poetry publish`)
- AWS CLI v2 (`aws codeartifact login --tool pip` is used)
- AWS credentials with permission to create CodeArtifact domains/repositories and publish to them
- Default region: `eu-west-1` (override with `-var aws_region=...`)

## Run

```bash
cd tests/simple
terraform init
terraform apply -auto-approve
terraform destroy -auto-approve
```

A successful apply ends with `[verify] PASS` in the local-exec output.

## Customization

- `name_prefix` — prefix applied to the CodeArtifact domain and repository names. Change it to run multiple tests in parallel without collisions.
- `aws_region` — target AWS region.

## Notes

- The `terraform_data.verify` resource is keyed on the package version via `triggers_replace`, so re-running `terraform apply` without bumping the lib version will not re-execute the publish or verify steps (matching the module's own behavior). To force a re-run: `terraform taint module.publish.terraform_data.build_and_publish_code` and `terraform taint terraform_data.verify`.
- Cleanup is complete via `terraform destroy`: CodeArtifact repositories and the domain are removed.
