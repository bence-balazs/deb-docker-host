#!/bin/bash
##
# Basic script to configure debian host whit this steps:
# Delete all already presented docker related packages
# Setup docker repository and install docker
# Setup rootless access to manage docker containers
# Add non root user
# Copy over root ssh pub key to the new user
set -euo pipefail;

# Enforce to run with sudo or root. exit 1
if [ "$(id -u)" -ne 0 ]; then
    echo "Must run with super user privileges."
    exit 1
fi

# Provides a usage statement, if the user does not supply an account name on the command line returns an exit 1.
if [ "$#" -lt 1 ]; then
    echo "Usable options:"
    echo "$0 2 [Setup rootless docker.]"
    echo "$0 3 <username> [Setup non root user.]"
    echo "$0 4 <username> [Do both options.]"
    exit 1
fi

setup_user() {
    local USER_NAME="$1"
    local USER_COMMENT="docker user"

    # Automatically generates password for the new account.
    USER_PASSWORD=$(date +%s%N | sha256sum | head -c16)

    # Informs the user if the account was not able to be created. exit 1.
    useradd -c "$USER_COMMENT" -m "$USER_NAME"

    if [ $? -ne 0 ]; then
        echo "User creation has failed!"
        exit 1
    fi

    # Set the password for the user.
    echo -e "$USER_PASSWORD\n$USER_PASSWORD" | passwd $USER_NAME
    passwd -q -e $USER_NAME

    if [ $? -ne 0 ]; then
        echo "Password change has failed!"
        exit 1
    fi

    # Setup docker rootless acces.
    sudo groupadd docker
    sudo usermod -aG docker $USER_NAME

    # Display the username,password, and host.
    echo "User name: $USER_NAME"
    echo "Password:  $USER_PASSWORD"
    echo "Host name: $(hostname)"
}

setup_docker() {
    # Make sure to remove all docker related packages.
    for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do 
        sudo apt-get remove $pkg; 
    done

    # Initialize docker repo.
    sudo apt-get update
    sudo apt-get install ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -y

    # Install docker from repository.
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

if [ "$1" = 2 ]; then
    echo "Setting up rootless docker..."
    
    setup_docker
fi
if [ "$1" = 3 ]; then
    echo "Setting up non root user..."
    
    setup_user $1
fi
if [ "$1" = 4 ]; then
    echo "Setting up rootless docker and non root user..."
    
    setup_docker
    setup_user $1
fi

exit 0
