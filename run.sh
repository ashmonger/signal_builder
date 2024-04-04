#!/bin/bash

set -euxo pipefail

do_setup () {
    LATEST=$(curl --silent "https://api.github.com/repos/signalapp/Signal-Desktop/releases/latest" | jq -r '.tag_name')

    DISTRO_RELEASE="$(lsb_release -rs)"
    CONTAINER_NAME="$(openssl rand -hex 16)"
    docker create --name $CONTAINER_NAME ubuntu:$DISTRO_RELEASE /build.sh
    docker cp $0 $CONTAINER_NAME:/build.sh
    docker start --attach $CONTAINER_NAME
    if ! [[ $? -eq 0 ]]; then
        echo "build has failed ..."
        exit 1
    fi
    docker cp $CONTAINER_NAME:/Signal-Desktop/release/Signal-${LATEST#v*}.AppImage $(pwd)
    docker rm $CONTAINER_NAME
}

do_build () {
    apt-get -y update
    apt-get -y install git curl python2 python3 git-lfs build-essential jq moreutils

    LATEST=$(curl --silent "https://api.github.com/repos/signalapp/Signal-Desktop/releases/latest" | jq -r '.tag_name')

    curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.34.0/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    git clone https://github.com/signalapp/Signal-Desktop.git
    cd Signal-Desktop
    git-lfs install
    git checkout "$LATEST"

    NODE_VERSION="$(jq -r '.engines.node' package.json)"
    jq '.build.linux.target|=["AppImage"]' package.json | sponge  package.json

    nvm install "$NODE_VERSION"
    nvm use

    npm install --global yarn

    yarn install --frozen-lockfile
    #yarn grunt
    yarn generate
    yarn build-release
}

if [[ "$(basename $0)" = "build.sh" ]]; then
    do_build
    exit 0
fi

do_setup
exit 0
