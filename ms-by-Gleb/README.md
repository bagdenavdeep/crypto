# Crypto for Bino

## Required
 - Redis
 - ethereum [Install](https://ethereum.gitbooks.io/frontier-guide/content/installing_linux.html), [local start](https://ethereum.gitbooks.io/frontier-guide/content/testing_contracts_and_transactions.html)

## Start ethereum localy
ethereum will be available on http://192.168.1.8:8110
`geth --datadir /home/cryptobino/testing/00/ --port 30310 --rpc --rpcaddr 192.168.1.8 --rpcport 8110 --networkid 4567890 --nodiscover --maxpeers 0 --vmdebug --verbosity 6 --pprof --pprofport 6110 console 2>> /home/cryptobino/testint/00/00.log`
