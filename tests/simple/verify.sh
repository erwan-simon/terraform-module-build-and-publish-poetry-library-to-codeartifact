#!/bin/bash
set -euo pipefail

domain_name=$1
repository_name=$2
region=$3
package_name=$4
expected_version=$5
expected_output=$6

workdir=$(mktemp -d)
trap 'rm -rf "${workdir}"' EXIT

echo "[verify] creating venv in ${workdir}"
python3 -m venv "${workdir}/venv"
# shellcheck disable=SC1091
source "${workdir}/venv/bin/activate"

pip install --quiet --upgrade pip

echo "[verify] configuring pip against CodeArtifact ${domain_name}/${repository_name} in ${region}"
aws codeartifact login \
  --tool pip \
  --domain "${domain_name}" \
  --repository "${repository_name}" \
  --region "${region}"

echo "[verify] installing ${package_name}==${expected_version}"
pip install --quiet "${package_name}==${expected_version}"

echo "[verify] checking transitive dependency 'requests' is installed"
if ! pip show requests >/dev/null 2>&1; then
  echo "[verify] FAIL: transitive dependency 'requests' was not installed"
  exit 1
fi

echo "[verify] running entrypoint"
actual_output=$(python3 -c "import tfmodule_codeartifact_test; print(tfmodule_codeartifact_test.run())")
echo "[verify] output: ${actual_output}"

if [[ "${actual_output}" != *"${expected_output}"* ]]; then
  echo "[verify] FAIL: expected output to contain '${expected_output}'"
  exit 1
fi

echo "[verify] PASS"
