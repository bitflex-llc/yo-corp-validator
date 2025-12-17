# YO Network Validator Node

Публичный репозиторий для быстрого развёртывания валидатора или публичной full-ноды сети YO (EVMOS). Скрипт разворачивает окружение на чистой Ubuntu 22.04, подтягивает genesis, настраивает конфиги и systemd сервис.

## Параметры сети
- Chain ID: `evmos_100892-1`
- Denom: `aevmos` (YO, 18 dec)
- RPC: `http://rpc.yonetwork.io:26657`
- JSON-RPC: `http://rpc.yonetwork.io:8545`
- Explorer: https://explorer.yonetwork.io
- Persistent peer: `c24d9aa369bf91e0e26c86d664b2c4fbc90d216f@rpc.yonetwork.io:26656`

## Требования
- Ubuntu 22.04 LTS, root доступ
- CPU 4+ cores, RAM 8–16 GB, SSD 200+ GB (NVMe предпочтительнее)
- Открытые порты: `26656` (p2p), `26657` (CometBFT RPC), `8545/8546` (JSON-RPC), `1317` (REST), `9090` (gRPC)

## Быстрый старт
```bash
apt update && apt install -y git
git clone https://github.com/YO-Corp/validator.git
cd validator

# по желанию меняем монникер
MONIKER=my-node ./scripts/setup.sh
```

Скрипт:
- ставит зависимости и Evmos `v20.0.0` (переменная `EVMOS_VERSION`)
- инициализирует `$EVMOS_HOME` (по умолчанию `/root/.evmosd`)
- копирует `config/genesis.json`
- прописывает persistent peer `rpc.yonetwork.io:26656`
- включает JSON-RPC / REST / gRPC
- создаёт и запускает `systemd` сервис `evmosd`

## Управление сервисом
- статус: `systemctl status evmosd`
- логи: `journalctl -u evmosd -f`
- рестарт: `systemctl restart evmosd`
- остановка: `systemctl stop evmosd`

## Проверка
```bash
curl -s localhost:26657/status | jq '.result.sync_info'
curl -s localhost:8545 \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

## Кастомизация
- `MONIKER` — имя ноды
- `EVMOS_HOME` — директория данных (по умолчанию `/root/.evmosd`)
- `PERSISTENT_PEERS` — список пиров, можно расширять через переменную окружения
- `MIN_GAS` — `minimum-gas-prices` (по умолчанию `0aevmos`)

## Безопасность
- Не коммитьте и не публикуйте `priv_validator_key.json`, `node_key.json` и файлы из `keyring-*`
- Сделайте бэкап ключей валидатора и храните отдельно от сервера
- Ограничьте доступ к RPC/JSON-RPC фаерволом или reverse-proxy, если не нужен публичный доступ

