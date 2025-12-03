#!/bin/sh
# add_user.sh
#
# Creates Docker configuration files for a new user.
# Usage:
#   /bin/sh scripts/add_user.sh
#
# -h, --help  Display this help message
#

set -e  # Exit on any error


SKIP_PROMPT=0

USERNAME_TPL=sample-user
COMPOSE_FILE_TPL=users/${USERNAME_TPL}.yml
ENV_FILE_TPL=users/${USERNAME_TPL}.env

PORT_SEQ_FILE=users/port_seq.txt
NETWORK_NUMBER_SEQ_FILE=users/network_number.txt


#####################################################################################################
#       Helper functions                                                                            #
#####################################################################################################

source scripts/util.sh

#
# Prints the help message.
#
print_help() {
  echo
  echo "Creates Docker configuration files for a new user."
  echo "Usage:"
  echo "  /bin/sh add_user.sh username [-h|--help]"
  echo
  echo "-h, --help        Display this help message."
  echo
}


#####################################################################################################


echo
echo "----- Generating environment file $ENV_FILE -----"
echo "Please provide the user information."
read -p "Username: " USERNAME
read -p "Name: " NAME
read -p "E-mail: " EMAIL

# Verify at least the username has been given
if [ " $USERNAME " == "  " ]
then
  error "ERROR: Incorrect usage. Please provide a username."
fi

COMPOSE_FILE="users/${USERNAME}.yml"
ENV_FILE="users/${USERNAME}.env"
CONTAINER="criu-jupyterlab-$USERNAME"

# Check if files exist
if [ -f "$COMPOSE_FILE" ] || [ -f "$ENV_FILE" ]
then
  echo
  confirm_or_abort \
    "The target environment and compose files exist.\nThis action will overwrite them. "
fi

# Random JupyterLab token generation
TOKEN=$(tr -dc A-Za-z0-9 < /dev/urandom | head -c 32)

cp "$ENV_FILE_TPL" "$ENV_FILE"
sed -e "s/$USERNAME_TPL/$USERNAME/" \
    -e "s/NAME/$NAME/" \
    -e "s/EMAIL/$EMAIL/" \
    -r -e "s/(JUPYTER_PASSWORD=)(.*)/\1$TOKEN/" \
    -i "$ENV_FILE"


echo
echo "----- Generating compose file $COMPOSE_FILE -----"

# Auto-increment port number
if [ -f "$PORT_SEQ_FILE" ]
then
  PORT=$(( $(cat "$PORT_SEQ_FILE") + 1 ))
  PORT_QUARTO=$(( $PORT + 10000 ))
else
  echo "The file with the last port number generated could not be found ($PORT_SEQ_FILE)."
  echo "Please provide a port numbers for this user."
  read -p "JupyterLab Port: " PORT
  read -p "Quarto preview Port: " PORT_QUARTO
fi

# Auto-increment network number
if [ -f "$NETWORK_NUMBER_SEQ_FILE" ]
then
  NETWORK_NUMBER=$(( $(cat "$NETWORK_NUMBER_SEQ_FILE") + 1 ))
else
  echo "The file with the last network number generated could not be found ($NETWORK_NUMBER_SEQ_FILE)."
  echo "Please provide a network number for this user."
  read -p "Network Number: " NETWORK_NUMBER
fi

cp "$COMPOSE_FILE_TPL" "$COMPOSE_FILE"
sed -e "s/$USERNAME_TPL/$USERNAME/" \
    -e "s/NAME/${NAME}/" \
    -e "s/EMAIL/${EMAIL}/" \
    -e "s/PORT_QUARTO/${PORT_QUARTO}/" \
    -e "s/PORT/${PORT}/" \
    -e "s/NETWORK_NUMBER/${NETWORK_NUMBER}/" \
    -i "$COMPOSE_FILE"


echo
echo "----- Starting container $CONTAINER -----"
docker compose -f "$COMPOSE_FILE" up -d $USERNAME


# Save last port number generated
echo $PORT > "$PORT_SEQ_FILE"
echo $NETWORK_NUMBER > "$NETWORK_NUMBER_SEQ_FILE"

# Generate unique URL to access the notebook
HOSTNAME=$(hostname)
URL="http://${HOSTNAME%%.*}:$PORT/?token=$TOKEN"
echo
echo "JupyterLab instance is running at $URL"
