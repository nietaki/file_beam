#!/usr/bin/env bash

# set -o nounset
# set -o xtrace

ANSIBLE_DIR="$(dirname "$0")"

# let's be serious here
export ANSIBLE_NOCOWS=1

pushd "$ANSIBLE_DIR/.."

MIX_ENV=prod mix distillery.release --env=prod
popd

pushd "$ANSIBLE_DIR"

ansible-playbook -i hosts deploy.yml

popd
