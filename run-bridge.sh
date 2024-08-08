#!/bin/bash

CHAIN_ID="private"
KEYRING_BACKEND="test"
NODE_TYPE="bridge"
CONFIG_DIR="root/.celestia-bridge-$CHAIN_ID"
NODE_NAME="bridge-${1:-0}"
CREDENTIALS_DIR="/credentials"
NODE_KEY_FILE="$CREDENTIALS_DIR/$NODE_NAME.key"
NODE_JWT_FILE="$CREDENTIALS_DIR/$NODE_NAME.jwt"
GENESIS_DIR="/genesis"
GENESIS_HASH_FILE="$GENESIS_DIR/genesis_hash"
PASSWORD="P@ssw0rd"

# Wait for the validator to set up and provision us via shared dirs
wait_for_provision() {
  echo ${NODE_NAME}
  echo "Waiting for the validator node to start"
  echo ${NODE_KEY_FILE}
  while [[ ! ( -e ${GENESIS_HASH_FILE} && -e ${NODE_KEY_FILE} ) ]]; do
    sleep 0.5
  done

  sleep 1 # let the validator finish setup
  echo "Validator is ready"
}

# Import the test account key shared by the validator
import_shared_key() {
  echo ${PASSWORD} | cel-key import ${NODE_NAME} ${NODE_KEY_FILE} \
    --keyring-backend=${KEYRING_BACKEND} \
    --p2p.network ${CHAIN_ID} \
    --node.type ${NODE_TYPE}
}

add_trusted_genesis() {
  local genesis_hash

  # Read the hash of the genesis block
  genesis_hash="$(cat "$GENESIS_HASH_FILE")"
  # and make it trusted in the node's config
  echo "Trusting a genesis: $genesis_hash"
  sed -i'.bak' "s/TrustedHash = .*/TrustedHash = $genesis_hash/" "$CONFIG_DIR/config.toml"
}

write_jwt_token() {
  echo "Saving jwt token to ${NODE_JWT_FILE}"
  echo ${CHAIN_ID}
  celestia bridge auth admin --p2p.network ${CHAIN_ID} > ${NODE_JWT_FILE}
}

main() {
  # Wait for a validator
  wait_for_provision
  # Import the key of test account
  import_shared_key
  # Initialize the bridge node
  celestia bridge init --p2p.network ${CHAIN_ID}
  # Trust the private blockchain
  add_trusted_genesis
  # Update the JWT token
  write_jwt_token
  # Start the bridge node
  echo "Running a brige node..."
  celestia bridge start \
    --core.ip validator \
    --keyring.accname ${NODE_NAME} \
    --p2p.network ${CHAIN_ID}
}

main