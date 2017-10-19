# crypto

Инструкция по установке и настройке приведена для macOS. Чтобы использовать на других ОС см. ссылки.

## Brew
Если у вас не установлен brew
```
$ /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
```

Актуальная команда https://brew.sh

## NodeJS
Следующим шагом будет установка nodejs
```
$ brew install node
```

Для других ОС https://nodejs.org/en/download/package-manager

## Truffle Framework
Затем устанавливаем truffle
```
$ npm install -g truffle
```

## TestRPC
Для локального тестирования используем testrpc
```
$ npm install -g ethereumjs-testrpc
```

Запускаем
```
$ testrpc --secure -u 0 -u 1 -u 2 -u 3 -u 4 -u 5 -u 6 -l 4712388
```

Клиент testrpc при запуске генерирует 10 аккаунтов. Опция `-u 0` это разблокировка первого аккаунта в списке. Разблокируем для того чтобы отправлять деньги от его имени. А `-l 4712388` это gasLimit.

### Ethereum-bridge
Если в контракте используем [oraclize](https://github.com/oraclize/ethereum-api) и необходимо тестировать локально, в таком случае устанавливаем [ethereum-bridge](https://github.com/oraclize/ethereum-bridge) эмулирующий oraclize локально. Клонируем репозиторий
```
$ git clone https://github.com/oraclize/ethereum-bridge
```
желательно в отдельную папку, и выполняем `npm install` находясь в склонированном репозитории. Убедитесь, что в текущей папке присутствует файл `package.json`. Запускаем
```
$ node bridge -H localhost:8545 --broadcast -a 0
```

## Geth
Для тестирования на testnet или mainnet необходима нода Эфириума [geth](https://github.com/ethereum/go-ethereum/wiki/geth)
```
$ brew tap ethereum/ethereum
$ brew install ethereum
```

### Create wallet
Для тестирования на testnet или mainnet у вас должны быть созданы кошельки. Создать их можно через [mist](https://github.com/ethereum/mist/releases) или [metamask](https://metamask.io/). Также возможен вариант создания с помощью `geth account new`

### Buy ether
Чтобы пополнить кошелек создаем https://gist.github.com в содержимом которого пишем адрес кошелька для пополнения. Заходим на сайт https://www.rinkeby.io и слева в меню находим Crypto Faucet. Вводим ссылку на созданный gist, затем выбираем необходимое количество ether для пополнения.

### Account import
Чтобы использовать созданные аккаунты необходимо их импортировать в geth
```
$ geth account import <keyfile>
```
  
Где `<keyfile>` это файл с private key. Аккаунты импортируются в локальный geth в папку `/$HOME/Library/Ethereum/keystore` и необходимо перенести их в папку `/$HOME/Library/Ethereum/rinkeby/keystore`

### Unlock account
Для разблокировки аккаунтов необходимо создать файл (например, с именем password), в котором с новой строки необходимо записать passphrase для каждого аккаунта.

### Run
Запускаем geth для работы с rinkeby
```
$ geth --rinkeby --rpc --rpcaddr localhost --rpcport 8545 --rpcapi=admin,db,miner,shh,txpool,personal,eth,net,web3,console --unlock="0, 1, 2, 3, 4, 5" --password /$HOME/password --fast --cache=1024
```

### Remove DB
Также полезная команда для удаления синхронизированной db
```
$ geth removedb --datadir=/$HOME/Library/Ethereum/rinkeby
```

### Truffle migrate
Переходим в папку с проектом и публикуем контракт в сети
```
$ truffle migrate --network rinkeby
```

### Truffle network
Проверить адрес опубликованного контракта можно командой
```
$ truffle network
```

### Truffle test
Запуск теста
```
$ truffle test --network rinkeby
```

На данном этапе тестами покрыта функциональность одновременного создания нескольких анонимных и обычных сделок, отлавливание эвентов и логирование используемого газа.
