#!/bin/bash

BRIDGE_COUNT="${1:-1}"
CHAIN_ID="private"
KEY_NAME="validator"
KEYRING_BACKEND="test"
CONFIG_DIR="root/.celestia-app"
NODE_NAME="validator-0"
VALIDATOR_COINS="1000000000000000utia"
DELEGATION_AMOUNT="5000000000utia"
CREDENTIALS_DIR="/credentials"
GENESIS_DIR="/genesis"
GENESIS_HASH_FILE="$GENESIS_DIR/genesis_hash"
PASSWORD="P@ssw0rd"

# Get the address of the node of given name
node_address() {
  local node_name="$1"
  local node_address

  node_address=$(celestia-appd keys show "$node_name" -a --keyring-backend="test")
  echo "$node_address"
}

# Waits for the given block to be created and returns it's hash
wait_for_block() {
  local block_num="$1"
  local block_hash=""

  # Wait for the block to be created 
  while [[ -z ${block_hash} ]]; do
    # `|| echo` fallbacks to an empty string in case it's not ready
    block_hash="$(celestia-appd query block ${block_num} 2>/dev/null | jq '.block_id.hash' || echo)"
    sleep 0.5
  done

  echo ${block_hash}
}

provision_bridge_nodes() {
    local genesis_hash
    local last_node_idx=$((BRIDGE_COUNT - 1))

    echo "Saving a genesis hash to $GENESIS_HASH_FILE"

    genesis_hash=$(wait_for_block 1)
    echo ${genesis_hash} > ${GENESIS_HASH_FILE}

    for node_idx in $(seq 0 ${last_node_idx}); do
      local bridge_name="bridge-$node_idx"
      local key_file="$CREDENTIALS_DIR/$bridge_name.key"
      local addr_file="$CREDENTIALS_DIR/$bridge_name.addr"

      if [ ! -e ${key_file} ]; then
        echo "Creating a new keys for the ${bridge_name}"
        celestia-appd keys add ${bridge_name} --keyring-backend "test"
        echo ${PASSWORD} | celestia-appd keys export ${bridge_name} 2> ${key_file}
        node_address ${bridge_name} > ${addr_file}
      else
        echo ${PASSWORD} | celestia-appd keys import ${bridge_name} ${key_file} \
          --keyring-backend=${KEYRING_BACKEND}
      fi
    done
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
    provision_bridge_nodes &
    startCelestiaApp
}

main