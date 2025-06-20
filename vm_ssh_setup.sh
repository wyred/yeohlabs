#!/bin/bash

# --- VARIABLES ---
PUBLIC_KEY_CONTENT="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAsqaolfv6xbE6PDskAu+c2po1oaD+HpVNePLLljAwdD yeohlabs_vm"

# The user for whom the SSH key will be installed.
# The script defaults to the user running it.
SSH_USER=$(whoami)

# SSH directory and authorized_keys file path.
SSH_DIR="/home/${SSH_USER}/.ssh"
AUTHORIZED_KEYS_FILE="${SSH_DIR}/authorized_keys"

# SSH configuration file path.
SSH_CONFIG_FILE="/etc/ssh/sshd_config"

# --- SCRIPT ---

# Ensure the script is run as root to modify sshd_config.
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Please use sudo." >&2
  exit 1
fi

# Check if the public key content is set.
if [ -z "$PUBLIC_KEY_CONTENT" ] || [[ "$PUBLIC_KEY_CONTENT" == "ssh-rsa AAAA..." ]]; then
    echo "ERROR: Please edit the script and paste your public key into the PUBLIC_KEY_CONTENT variable." >&2
    exit 1
fi


echo "--- Starting SSH setup for user: ${SSH_USER} ---"

# Create .ssh directory if it doesn't exist and set permissions.
if [ ! -d "${SSH_DIR}" ]; then
  echo "Creating ${SSH_DIR} directory..."
  mkdir -p "${SSH_DIR}"
  chown "${SSH_USER}:${SSH_USER}" "${SSH_DIR}"
  chmod 700 "${SSH_DIR}"
fi

# Append the public key to authorized_keys, adding a newline first if the file already exists and doesn't end with one.
echo "Installing public key for ${SSH_USER}..."
( [ -f "${AUTHORIZED_KEYS_FILE}" ] && [ -s "${AUTHORIZED_KEYS_FILE}" ] && [[ $(tail -c1 "${AUTHORIZED_KEYS_FILE}") != '' ]] && echo '' ; echo "${PUBLIC_KEY_CONTENT}" ) >> "${AUTHORIZED_KEYS_FILE}"

# Set correct permissions for the authorized_keys file.
echo "Setting permissions for ${AUTHORIZED_KEYS_FILE}..."
chown "${SSH_USER}:${SSH_USER}" "${AUTHORIZED_KEYS_FILE}"
chmod 600 "${AUTHORIZED_KEYS_FILE}"

echo "Public key installed successfully."

# Disable password authentication in sshd_config.
echo "Disabling password authentication in SSH configuration..."
sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' "${SSH_CONFIG_FILE}"

# Enable and restart the SSH service to apply changes.
echo "Enabling and restarting SSH service..."
if command -v systemctl >/dev/null 2>&1; then
  systemctl enable ssh || systemctl enable sshd
  systemctl restart ssh || systemctl restart sshd
elif command -v service >/dev/null 2>&1; then
  service ssh restart || service sshd restart
else
  echo "ERROR: Could not find a way to restart the SSH service. Please restart it manually." >&2
  exit 1
fi

echo "--- SSH setup complete! ---"
echo "Password login has been disabled. Please use your SSH key to log in."
