#!/bin/bash

account_id=$(aws sts get-caller-identity --query Account --output text)
pyproject_file_path=$1
artifact_repository_domain_name=$2
artifact_repository_endpoint=$3

cd $pyproject_file_path

if [ -z "${artifact_repository_endpoint}" ];
then
  echo "No dependency artifact repository set"
else
  artifact_repository_token=$(aws codeartifact get-authorization-token \
    --domain $artifact_repository_domain_name \
    --domain-owner $account_id \
    --query authorizationToken \
    --output text)
  poetry config repositories.target ${artifact_repository_endpoint}
  export POETRY_HTTP_BASIC_TARGET_USERNAME=aws
  export POETRY_HTTP_BASIC_TARGET_PASSWORD=$artifact_repository_token

  artifact_repository_name=$(echo "${artifact_repository_endpoint%/}" | sed -E 's|.*/pypi/([^/]+)$|\1|')
  package_name=$(poetry version | awk '{print $1}')
  package_version=$(poetry version --short)

  existing_version=$(aws codeartifact list-package-versions \
    --domain "$artifact_repository_domain_name" \
    --domain-owner "$account_id" \
    --repository "$artifact_repository_name" \
    --format pypi \
    --package "$package_name" \
    --query "versions[?version=='$package_version'].version" \
    --output text 2>/dev/null || echo "")

  if [ -n "$existing_version" ]; then
    printf '\033[33m[warning] version %s of %s already published to %s, skipping publish\033[0m\n' \
      "$package_version" "$package_name" "$artifact_repository_name"
    cd -
    exit 0
  fi
fi

rm -rf dist

if ! poetry publish --build --no-interaction -r target;
then
  echo "Cannot publish library"
  exit 1
fi

if [ -n "${artifact_repository_endpoint}" ]; then
  sleep 5

  published_version=$(aws codeartifact list-package-versions \
    --domain "$artifact_repository_domain_name" \
    --domain-owner "$account_id" \
    --repository "$artifact_repository_name" \
    --format pypi \
    --package "$package_name" \
    --query "versions[?version=='$package_version'].version" \
    --output text 2>/dev/null || echo "")

  if [ -z "$published_version" ]; then
    printf '\033[31m[error] poetry publish reported success but version %s of %s was not found in %s\033[0m\n' \
      "$package_version" "$package_name" "$artifact_repository_name"
    exit 1
  fi

  printf '\033[32m[ok] version %s of %s confirmed published to %s\033[0m\n' \
    "$package_version" "$package_name" "$artifact_repository_name"
fi

cd -
