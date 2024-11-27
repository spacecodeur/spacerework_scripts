#!/bin/bash

LOCK_FILE="/var/log/installBase_to_computeInstanceService__setup-done"
STEP_FILE="/var/log/installBase_to_computeInstanceService__setup-step"

# Vérifier si le script a déjà été exécuté
if [ -f "$LOCK_FILE" ]; then
    echo "Setup script already completed. Exiting."
    exit 0
fi

# Définir le prochain step à exécuter (pour reprise)
function set_step {
    local step="$1"
    echo "$step" | sudo tee "$STEP_FILE" > /dev/null
    CURRENT_STEP="$step"
}

# Lire le step actuel
CURRENT_STEP=$(cat "$STEP_FILE" 2>/dev/null || echo "start")

# Debug : afficher la valeur de CURRENT_STEP
echo "CURRENT_STEP avant étape : '$CURRENT_STEP'"

# Étape : Mettre à jour les paquets
if [ "$CURRENT_STEP" == "start" ]; then
    echo "Updating package repository..."
    sudo yum update -y || exit 1
    set_step "installGit"
fi

# Étape : Installer git
if [ "$CURRENT_STEP" == "installGit" ]; then
    echo "Installing git..."
    sudo yum install -y git || exit 1
    set_step "installDocker"
fi

# Étape : Installer Docker
if [ "$CURRENT_STEP" == "installDocker" ]; then
    echo "Installing Docker..."
    sudo yum install -y docker || exit 1
    set_step "startDocker"
fi

# Étape : Démarrer Docker
if [ "$CURRENT_STEP" == "startDocker" ]; then
    echo "Starting Docker service..."
    sudo service docker start || exit 1
    sudo chkconfig docker on || exit 1
    set_step "verifyDocker"
fi

# Étape : Vérifier Docker
if [ "$CURRENT_STEP" == "verifyDocker" ]; then
    if docker --version &>/dev/null && sudo service docker status | grep -q 'running'; then
        echo "Docker is installed and running. Version: $(docker --version)"
    else
        echo "Docker installation or startup failed."
        exit 1
    fi
    set_step "installDockerCompose"
fi

# Étape : Installer Docker Compose
if [ "$CURRENT_STEP" == "installDockerCompose" ]; then
    echo "Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose || exit 1
    sudo chmod +x /usr/local/bin/docker-compose || exit 1
    set_step "verifyDockerCompose"
fi

# Étape : Vérifier Docker Compose
if [ "$CURRENT_STEP" == "verifyDockerCompose" ]; then
    if docker-compose --version &>/dev/null; then
        echo "Docker Compose is installed. Version: $(docker compose version)"
    else
        echo "Docker Compose installation failed."
        exit 1
    fi
    set_step "complete"
fi

# Étape finale : Marquer comme terminé
if [ "$CURRENT_STEP" == "complete" ]; then
    echo "Install Base completed successfully."
    sudo touch "$LOCK_FILE"
    sudo rm -f "$STEP_FILE"
    exit 0
fi
