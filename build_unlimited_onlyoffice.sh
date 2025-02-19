#!/bin/bash

WORK_DIR="${PWD}/onlyoffice-build"
BUILD_BRANCH="$1"  # release/v8.3.0
PRODUCT_VERSION=${2:-8.3.0}
UNLIMITED_ORGANIZATION=${3:-xyz}

echo $PRODUCT_VERSION
echo $UNLIMITED_ORGANIZATION
# Define the expected path of the docservice binary
DOCSERVICE_PATH="${WORK_DIR}/build_tools/out/linux_64/onlyoffice/documentserver/server/DocService/docservice"

# Function to execute a command inside a Docker container
docker_exec() {
    local container_name="$1"
    local command="$2"
    sudo docker exec -it "$container_name" bash -c "$command"
}

prepare_build_env() {
    docker_exec oo-builder "apt update && apt install -y python3 python3-pip sudo"
    docker_exec oo-builder "ln -s /usr/bin/python3 /usr/bin/python"
}

install_docker() {
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

build_oo() {
    sed -i '/base.update_repositories(repositories)/a \  exit(0)' make.py
    sed -i 's/if (nodejs_cur < 16000):/if (nodejs_cur < 20000):/' tools/linux/deps.py
    sed -i 's|setup_16.x|setup_20.x|' tools/linux/deps.py

    if ! sudo docker ps | grep -q oo-builder; then
        sudo docker run -it -d -v $(pwd):/build_tools --name oo-builder ubuntu:22.04 bash
    else
        echo "Container 'oo-builder' already exists. Skipping Docker container creation."
    fi

    prepare_build_env
    docker_exec oo-builder "sed -i '/exit(0)/{N;/exit(0)/{N;s/\nexit(0)//g;}}' /build_tools/make.py"
    docker_exec oo-builder "cd /build_tools/tools/linux && python3 automate.py server --branch='$BUILD_BRANCH'"

    docker_exec oo-builder "sed -i 's/^exports.LICENSE_CONNECTIONS = 20;/exports.LICENSE_CONNECTIONS = 99999;/g' /server/Common/sources/constants.js"
    docker_exec oo-builder "sed -i 's/^exports.LICENSE_USERS = 3;/exports.LICENSE_USERS = 99999;/g' /server/Common/sources/constants.js"

    docker_exec oo-builder "sed -i '/# update/,/base.configure_common_apps()/ { /base.configure_common_apps/!s/^/# / }' /build_tools/make.py"
    docker_exec oo-builder "cd /build_tools/tools/linux && python3 automate.py server --branch='$BUILD_BRANCH'"
}

build_deb() {
    echo "Building deb packages..."
    local DEB_NAME=$(sudo find "$WORK_DIR/build_tools" -name "onlyoffice-documentserver_*.deb" | head -n 1 | xargs -n 1 basename)
    

    if [ -n "$DEB_NAME" ]; then
        echo "Found existing .deb package: $DEB_NAME"
        read -p "Do you want to rebuild the .deb package? (y/n): " REBUILD_CHOICE
        if [[ "$REBUILD_CHOICE" != "y" ]]; then
            echo "Skipping .deb package build and proceeding with the existing package."
            build_image
            return
        fi
    fi

    cd "$WORK_DIR" || exit 1

    [ -d "unlimited-onlyoffice-package-builder" ] && (cd unlimited-onlyoffice-package-builder && git pull) || git clone https://github.com/btactic-oo/unlimited-onlyoffice-package-builder.git

    cd "$WORK_DIR"/unlimited-onlyoffice-package-builder/deb_build || exit 1

    sudo docker images | grep -q "oo-deb-builder" || sudo docker build -t oo-deb-builder -f Dockerfile-manual-debian-11 .

    if ! sudo docker ps -a --format "{{.Names}}" | grep -q "^oo-deb-builder$"; then
        echo "Starting new container 'oo-deb-builder'..."
        sudo docker run -it -d \
            --env PRODUCT_VERSION=$PRODUCT_VERSION \
            --env BUILD_NUMBER=1 \
            --env TAG_SUFFIX=-${UNLIMITED_ORGANIZATION} \
            --env UNLIMITED_ORGANIZATION=${UNLIMITED_ORGANIZATION}-oo \
            --env DEBIAN_PACKAGE_SUFFIX=-${UNLIMITED_ORGANIZATION}-oo \
            -v ${WORK_DIR}/build_tools:/build_tools \
            --name oo-deb-builder \
            oo-deb-builder
    else
        echo "Container 'oo-deb-builder' already exists. Skipping creation."
    fi

    docker_exec oo-deb-builder "cd / && git clone https://github.com/ONLYOFFICE/document-server-package.git"
    docker_exec oo-deb-builder "cd /document-server-package && git checkout $BUILD_BRANCH"
    docker_exec oo-deb-builder "cd /document-server-package && \
        echo 'deb_dependencies: \$(DEB_DEPS)' >> Makefile"
    docker_exec oo-deb-builder "cd /document-server-package && \
        PRODUCT_VERSION="8.3.0" BUILD_NUMBER="1-xyz" make deb_dependencies"
    docker_exec oo-deb-builder "cd /document-server-package/deb/build && apt-get -qq build-dep -y ./"
    docker_exec oo-deb-builder  "cd /document-server-package && \
        PRODUCT_VERSION="8.3.0" BUILD_NUMBER="1-xyz" make deb"
    
    docker_exec oo-deb-builder "cp /document-server-package/deb/*.deb /build_tools"
    ## Starting building image
    build_image 
}

build_image() {
    cd "$WORK_DIR"
    
    # Find the deb package name
    local DEB_NAME=$(sudo find "$WORK_DIR/build_tools" -name "onlyoffice-documentserver_*.deb" | head -n 1 | xargs -n 1 basename)
    
    # Check if Docker-DocumentServer directory exists
    if [ ! -d "Docker-DocumentServer" ]; then
        # If not, clone the repository
        git clone https://github.com/thomisus/Docker-DocumentServer.git
    fi
    cd Docker-DocumentServer
    git clean -fdx
    cp $WORK_DIR/build_tools/*.deb .
    # Replace wget with COPY in Dockerfile
    sed -i "s|RUN    wget -q -P /tmp [^ ]*onlyoffice-documentserver_[^ ]*amd64.deb|COPY ./$DEB_NAME /tmp|g" Dockerfile
    sed -i '/COPY .\/onlyoffice-documentserver_8.3.0-1-xyz_amd64.deb/ {n; s|^|RUN |; s|^RUN\s*|RUN |}' Dockerfile
    sed -i "s|apt-get -yq install /tmp/onlyoffice-documentserver_[^ ]*.deb|apt-get -yq install /tmp/$DEB_NAME|g" Dockerfile
    sed -i "s|rm -f /tmp/onlyoffice-documentserver_[^ ]*.deb|rm -f /tmp/$DEB_NAME|g" Dockerfile
    sed -i "s|rm -f /tmp/\$PACKAGE_FILE|rm -rf /tmp/\$PACKAGE_FILE|g" Dockerfile
    sed -i '/onlyoffice-documentserver/ s/\"//g' Dockerfile
    sed -i '/COPY .*onlyoffice-documentserver.*\/tmp/s/.....$//' Dockerfile

    echo "Building docker images..."
    sudo docker build -t unlimited-onlyoffice .
}

command -v docker &>/dev/null || install_docker

[[ -d "$WORK_DIR" ]] || mkdir "$WORK_DIR"
cd "$WORK_DIR"
git clone https://github.com/ONLYOFFICE/build_tools.git

cd build_tools
git checkout "$BUILD_BRANCH"

if [ -f "$DOCSERVICE_PATH" ]; then
    echo "A previous build of 'docservice' was found at: $DOCSERVICE_PATH"
    read -p "Do you want to continue with this build? (y/n): " choice
    case "$choice" in
        y|Y ) 
            echo "Continuing with the existing build."
            build_deb
            ;;
        n|N ) 
            echo "Starting a new build..."
            build_oo
            ;;
        * ) 
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
else
    echo "No previous build found. Starting a new build..."
    build_oo
fi
