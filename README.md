# YO Network Validator Node

Public repository for quickly deploying a validator or public full node for the YO (EVMOS) network. The script prepares a fresh Ubuntu 22.04 host, downloads the genesis file, configures node settings, and installs a systemd service.

## Network Parameters
- Chain ID: `evmos_100892-1`
- Denom: `aevmos` (YO, 18 dec)
- RPC: `http://rpc.yonetwork.io:26657`
- JSON-RPC: `http://rpc.yonetwork.io:8545`
- Explorer: https://explorer.yonetwork.io
- Persistent peer: `c24d9aa369bf91e0e26c86d664b2c4fbc90d216f@rpc.yonetwork.io:26656`

## Requirements
- Ubuntu 22.04 LTS with root access
- CPU 4+ cores, RAM 8-16 GB, SSD 200+ GB (NVMe preferred)
- Open ports: `26656` (p2p), `26657` (CometBFT RPC), `8545/8546` (JSON-RPC), `1317` (REST), `9090` (gRPC)

## Quick Start
```bash
apt update && apt install -y git
git clone https://github.com/YO-Corp/validator.git
cd validator

# optionally set a custom moniker
MONIKER=my-node ./scripts/setup.sh
```

The script:
- installs dependencies and Evmos `v20.0.0` (configurable via `EVMOS_VERSION`)
- initializes `$EVMOS_HOME` (defaults to `/root/.evmosd`)
- copies `config/genesis.json`
- sets persistent peer `rpc.yonetwork.io:26656`
- enables JSON-RPC / REST / gRPC
- creates and starts the `evmosd` systemd service

## Service Management
- status: `systemctl status evmosd`
- logs: `journalctl -u evmosd -f`
- restart: `systemctl restart evmosd`
- stop: `systemctl stop evmosd`

## Verification
```bash
curl -s localhost:26657/status | jq '.result.sync_info'
curl -s localhost:8545 \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

## Customization
- `MONIKER` - node name
- `EVMOS_HOME` - data directory (default `/root/.evmosd`)
- `PERSISTENT_PEERS` - comma-separated peer list; extend via environment variable
- `MIN_GAS` - `minimum-gas-prices` (default `0aevmos`)

## Security
- Do not commit or publish `priv_validator_key.json`, `node_key.json`, or files from `keyring-*`
- Back up validator keys and store them off the server
- Restrict RPC/JSON-RPC with a firewall or reverse proxy if public access is not required
