#!/bin/bash

# Run:
# nohup sh startEthereum.sh >&/var/log/geth.log &

# Необходим как минимум один аккаунт который должен быть разблокирован
# Пароль в файлике password
# geth account import privateKey
# cp ~/.ethereum/keystore/key ../rinkeby/keystore/

geth --rinkeby --rpc --rpcaddr localhost --rpcport 8545 --rpcapi=personal,eth,web3 --fast --cache=1024 --unlock="0xC82d0554D5ee7AC2e2eb1FBE0400De426DD2CFC5" --password $HOME/binomo/crypto/microservice/password
