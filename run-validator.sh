#!/bin/bash

CHAIN_ID="private"
KEY_NAME="validator"
KEYRING_BACKEND="test"
CONFIG_DIR="root/.celestia-app"
NODE_NAME="validator-0"
VALIDATOR_COINS="1000000000000000utia"
DELEGATION_AMOUNT="5000000000utia"

# Get the address of the node of given name
node_address() {
  local node_name="$1"
  local node_address

  node_address=$(celestia-appd keys show "$node_name" -a --keyring-backend="test")
  echo "$node_address"
}

# Set up the validator for a private alone network.
# Based on
# https://github.com/celestiaorg/celestia-app/blob/main/scripts/single-node.sh
setup_private_validator() {
    local validator_addr

    echo "Initializing validator and node config files..."
    celestia-appd init ${CHAIN_ID} --chain-id ${CHAIN_ID}

    echo "Adding a new key to the keyring..."
    celestia-appd keys add ${NODE_NAME} --keyring-backend=${KEYRING_BACKEND}
    validator_addr=$(node_address ${NODE_NAME})

    echo "Adding genesis account..."
    celestia-appd add-genesis-account ${validator_addr} ${VALIDATOR_COINS}

    echo "Creating a genesis tx..."
    celestia-appd gentx ${NODE_NAME} ${DELEGATION_AMOUNT} \
      --keyring-backend=${KEYRING_BACKEND} \
      --chain-id ${CHAIN_ID}

    echo "Collecting genesis txs..."
    celestia-appd collect-gentxs

    # Override the default RPC servier listening address
    sed -i'.bak' 's#"tcp://127.0.0.1:26657"#"tcp://0.0.0.0:26657"#g' "${CONFIG_DIR}"/config/config.toml

    # Enable transaction indexing
    sed -i'.bak' 's#"null"#"kv"#g' "${CONFIG_DIR}"/config/config.toml

    # Override the log level to debug
    # sed -i'.bak' 's#log_level = "info"#log_level = "debug"#g' "${CONFIG_DIR}"/config/config.toml
}

startCelestiaApp() {
    echo "Starting celestia-app..."
    celestia-appd start --api.enable --grpc.enable
}

main() {
    setup_private_validator
    startCelestiaApp
}

main