#!/bin/bash

set -e

GIT_REPO_URL="git@github.com:Giorgi-Sekhniashvili/anonym-chat.git"

CLONE_DIR="/root/projects"

PROJECT_NAME="anonym-chat"

CYAN="\e[36m"

GREEN="\e[32m"

MAGENTA="\e[35m"

RESET="\e[0m"

if [ "$1" = "h" ] || [ "$1" = "help" ]; then

  echo -e "${MAGENTA}Usage:${RESET}"

  echo " ./anonym.sh [i|install|h|help]"

  echo " - i or install: Perform full installation and project deployment."

  echo " - h or help: Display this help message."

  exit 0

fi

INSTALL_MODE="false"

if [ "$1" = "i" ] || [ "$1" = "install" ]; then

  INSTALL_MODE="true"

fi

if [ "$INSTALL_MODE" != "true" ]; then

  echo -e "${MAGENTA}No valid argument provided. Use 'install' for full setup or 'help' for usage.${RESET}"

  exit 0

fi

is_installed() {

    dpkg -l | grep -q "^ii $1 "

}

print_step() {

  echo -e "${CYAN}====================================================${RESET}"

  echo -e "${MAGENTA}=== Step $1: $2 ===${RESET}"

  echo -e "${CYAN}====================================================${RESET}"

}

print_complete() {

  echo -e "${GREEN}Step $1 completed successfully!${RESET}\n"

}

print_step 1 "Update and upgrade the system"

apt update -y

apt upgrade -y

apt autoremove -y

print_complete 1

if command -v figlet >/dev/null 2>&1; then

  figlet -f slant "$PROJECT_NAME"

else

  echo -e "${MAGENTA}=== $PROJECT_NAME Setup ===${RESET}"

fi

print_step 2 "Install essential packages"

for pkg in curl git figlet ca-certificates; do

    if ! is_installed "$pkg"; then

        apt install -y "$pkg"

    else

        echo -e "${GREEN}$pkg is already installed.${RESET}"

    fi

done

print_complete 2

print_step 3 "Install Docker"

if ! is_installed "docker-ce"; then

    install -m 0755 -d /etc/apt/keyrings

    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc

    chmod a+r /etc/apt/keyrings/docker.asc

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt update -y

    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

else

    echo -e "${GREEN}Docker is already installed.${RESET}"

fi

print_complete 3

print_step 4 "Set up Git SSH key for private repo access"

if [ ! -f ~/.ssh/id_ed25519 ]; then

    ssh-keygen -t ed25519 -C 'prod@anonym.com' -f ~/.ssh/id_ed25519 -N ''

fi

PUBLIC_KEY=$(cat ~/.ssh/id_ed25519.pub)

echo -e "${CYAN}Public SSH key for GitHub:${RESET}"

echo "$PUBLIC_KEY"

echo -e "${MAGENTA}Add this public key to your GitHub account at: https://github.com/settings/keys${RESET}"

read -p "Press Enter after adding the key to GitHub and testing access (e.g., ssh -T git@github.com)..."

print_complete 4

print_step 5 "Clone the private Git repo"

mkdir -p $CLONE_DIR

chown $USER:$USER $CLONE_DIR

BRNACH=""
echo "Raw \$2: [$2]"
printf 'Bytes of \$2: '
printf '%s' "$2" | od -c
if [ -n "$2" ]; then
	BRANCH="-b $2"
fi

echo "GIT_SSH_COMMAND=\"ssh -o StrictHostKeyChecking=no\" git clone $BRANCH $GIT_REPO_URL $CLONE_DIR/anonym-chat"
if ! GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no" git clone "$BRANCH" "$GIT_REPO_URL" "$CLONE_DIR/anonym-chat"; then


  echo -e "${MAGENTA}Git clone failed. Please check if the SSH public key has been added to the repository's deploy keys at: https://github.com/Giorgi-Sekhniashvili/anonym-chat/settings/keys${RESET}"

  exit 1

fi

print_complete 5

print_step 6 "Configure .env and Dockerize the project"

PROJECT_DIR="$CLONE_DIR/$(basename $GIT_REPO_URL .git)"

ENV_EXAMPLE="$PROJECT_DIR/.env.example"

ENV_FILE="$PROJECT_DIR/.env"

if [ -f "$ENV_EXAMPLE" ]; then

  touch "$ENV_FILE"

  chown $USER:$USER "$ENV_FILE"

  > "$ENV_FILE"

  grep -v '^#' "$ENV_EXAMPLE" | grep '=' | while read -r line ; do

      key=$(echo "$line" | cut -d '=' -f1)

      default=$(echo "$line" | cut -d '=' -f2-)

      echo -e "${CYAN}Enter value for $key (default: $default): ${RESET}"

      read input < /dev/tty

      value=${input:-$default}

      echo "$key=$value" >> "$ENV_FILE"

  done

  echo -e "${GREEN}.env file created successfully!${RESET}"

else

  echo -e "${MAGENTA}.env.example not found. Skipping .env configuration.${RESET}"

fi

cd $PROJECT_DIR && docker compose -f docker-compose.prod.yml up -d

echo -e "${GREEN}Docker containers started!${RESET}"

cd $PROJECT_DIR && docker compose exec -it backend uv run alembic upgrade heads

print_complete 6

echo -e "${MAGENTA}Setup complete! Docker is installed and ready. Your web app should now be running via Docker Compose.${RESET}"


