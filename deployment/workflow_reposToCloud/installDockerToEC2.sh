#!/bin/bash

LOCK_FILE="/var/log/docker-setup-done"
STEP_FILE="/tmp/docker-setup-step"

# Vérifier si le script a déjà été exécuté
if [ -f "$LOCK_FILE" ]; then
    echo "Setup script already completed. Exiting."
    exit 0
fi

# Définir le prochain step à exécuter (pour reprise)
function set_step {
    echo "$1" > "$STEP_FILE"
}

# Lire le step actuel
CURRENT_STEP=$(cat "$STEP_FILE" 2>/dev/null || echo "start")

# Étape : Mettre à jour les paquets
if [ "$CURRENT_STEP" == "start" ]; then
    echo "Updating package repository..."
    sudo yum update -y || exit 1
    set_step "install_docker"
fi

# Étape : Installer Docker
if [ "$CURRENT_STEP" == "install_docker" ]; then
    echo "Installing Docker..."
    sudo yum install -y docker || exit 1
    set_step "start_docker"
fi

# Étape : Démarrer Docker
if [ "$CURRENT_STEP" == "start_docker" ]; then
    echo "Starting Docker service..."
    sudo service docker start || exit 1
    sudo chkconfig docker on || exit 1
    set_step "verify_docker"
fi

# Étape : Vérifier Docker
if [ "$CURRENT_STEP" == "verify_docker" ]; then
    if docker --version &>/dev/null && sudo service docker status | grep -q 'running'; then
        echo "Docker is installed and running. Version: $(docker --version)"
    else
        echo "Docker installation or startup failed."
        exit 1
    fi
    set_step "install_docker_compose"
fi

# Étape : Installer Docker Compose
if [ "$CURRENT_STEP" == "install_docker_compose" ]; then
    echo "Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose || exit 1
    sudo chmod +x /usr/local/bin/docker-compose || exit 1
    set_step "verify_docker_compose"
fi

# Étape : Vérifier Docker Compose
if [ "$CURRENT_STEP" == "verify_docker_compose" ]; then
    if docker compose version &>/dev/null; then
        echo "Docker Compose is installed. Version: $(docker compose version)"
    else
        echo "Docker Compose installation failed."
        exit 1
    fi
    set_step "complete"
fi

# Étape finale : Marquer comme terminé
if [ "$CURRENT_STEP" == "complete" ]; then
    echo "Docker and Docker Compose installation completed successfully."
    touch "$LOCK_FILE"
    rm -f "$STEP_FILE"
    exit 0
fi