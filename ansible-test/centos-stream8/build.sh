#!/bin/bash
# Builds a centos-stream8 image suitable for use with ansible-test
# Based on https://github.com/ansible/distro-test-containers/blob/c4fe28818f5a33b675652637e3057bafe50039ee/centos8-test-container/Dockerfile

SCRIPT_DIR=$(cd `dirname $0` && pwd -P)
DEPENDENCIES="$(cat ${SCRIPT_DIR}/dependencies.txt | tr '\n' ' ')"

build=$(buildah from quay.io/centos/centos:stream8)
buildah run "${build}" -- /bin/bash -c "dnf update -y && dnf install --allowerasing -y ${DEPENDENCIES} && dnf clean all"

# Extra python dependencies
buildah run --volume ${SCRIPT_DIR}:/tmp/src:z "${build}" -- /bin/bash -c "pip3 install -r /tmp/src/requirements.txt"

# Cows are a good reminder that these are not for production use :)
buildah run "${build}" -- /bin/bash -c "dnf -y install epel-release && dnf -y install cowsay && dnf -y remove epel-release && dnf clean all"
buildah config --env ANSIBLE_NOCOWS=0 "${build}"

# Ansible-specific setup: Generate new SSH host keys, remove requiretty, set up a default inventory
buildah run "${build}" -- /bin/bash -c "ssh-keygen -A && sed -i -e 's/^\(Defaults\s*requiretty\)/#--- \1/' /etc/sudoers"
buildah run "${build}" -- /bin/bash -c "mkdir -p /etc/ansible && echo -e '[local]\nlocalhost ansible_connection=local' > /etc/ansible/hosts"

# Save space by removing some unnecessary files (~50MB)
buildah run "${build}" -- /bin/bash -c "rm -rf /usr/share/man/* /usr/share/doc/* /usr/share/fonts/*"
buildah run "${build}" -- /bin/bash -c "find /usr/lib/locale -mindepth 1 -maxdepth 1 -type d -not \( -name 'en_US.utf8' -o -name 'POSIX' \) -exec rm -rf '{}' +"

# TODO: What is the container env variable used for ?
buildah config --env container=docker "${build}"
buildah config --cmd "/usr/sbin/init" "${build}"
buildah commit "${build}" "${1:-localhost/test-image:centos-stream8}"
