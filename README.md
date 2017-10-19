# Project CRYPTO

Инструкция по установке и настройке компонент приведена для macOS. Чтобы использовать на других ОС, см. ссылки.

## Homebrew
Устанавливаем менеджер пакетов Homebrew. Он потребуется для установки последующих компонент.
```
$ /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
```

Доп. инф: https://brew.sh/

## NodeJS
Установливаем nodejs
```
$ brew install node
```

Доп. инф: https://nodejs.org/en/

## Truffle Framework
Устанавливаем truffle для публикации смарт-контрактов
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

Приведенные выше опции генерируют 10 аккаунтов. Опция `-u 0` разблокирует 1-ый аккаунт в списке. Предварительная разблокировка удобна тем, что позволяет отправлять деньги без доп. запроса пароля. Опция `-l 4712388` задает лимит газа.

### Ethereum-bridge
Если в контракте используем [oraclize](https://github.com/oraclize/ethereum-api) и необходимо тестировать локально, в таком случае устанавливаем [ethereum-bridge](https://github.com/oraclize/ethereum-bridge) эмулирующий oraclize локально. Клонируем репозиторий (желательно в отдельную папку)
```
$ git clone https://github.com/oraclize/ethereum-bridge
```
Затем выполняем `npm install`, находясь в папке с клоном репозитория. Убедитесь, что в текущей папке присутствует файл `package.json`. Запускаем
```
$ node bridge -H localhost:8545 --broadcast -a 0
```

## Geth
Для тестирования на testnet или mainnet необходима локальная нода Эфириума [geth](https://github.com/ethereum/go-ethereum/wiki/geth)
```
$ brew tap ethereum/ethereum
$ brew install ethereum
```

### Create wallet
Для тестирования на testnet или mainnet у вас должны быть созданы кошельки. Создать их можно через [mist](https://github.com/ethereum/mist/releases) или [metamask](https://metamask.io/). Также возможен вариант создания с помощью `geth account new`

### Buy ether
Чтобы пополнить кошелек создаем https://gist.github.com, в содержимом которого пишем адрес кошелька для пополнения. Заходим на сайт https://www.rinkeby.io и слева в меню находим Crypto Faucet. Вводим ссылку на созданный gist, затем выбираем необходимое количество Ether для пополнения.

### Account import
Чтобы использовать созданные аккаунты необходимо их импортировать в geth
```
$ geth account import <keyfile>
```
где `<keyfile>` - это файл с приватным ключом. Аккаунты импортируются в локальный geth в папку `/$HOME/Library/Ethereum/keystore`. Их необходимо перенести в папку `/$HOME/Library/Ethereum/rinkeby/keystore`

### Unlock account
Для разблокировки аккаунтов необходимо создать файл (например, с именем password), в котором с новой строки необходимо записать passphrase для каждого аккаунта.

### Run
Запускаем geth для работы с rinkeby
```
$ geth --rinkeby --rpc --rpcaddr localhost --rpcport 8545 --rpcapi=admin,db,miner,shh,txpool,personal,eth,net,web3,console --unlock="0, 1, 2, 3, 4, 5" --password /$HOME/password --fast --cache=1024
```

### Remove DB
Полезная команда для удаления локального блокчейна:
```
$ geth removedb --datadir=/$HOME/Library/Ethereum/rinkeby
```

### Truffle migrate
Публикация контракта в блокчейн (с указанием сети):
```
$ truffle migrate --network rinkeby
```

### Truffle network
Проверить адрес опубликованного контракта можно командой
```
$ truffle network
```

### Truffle test
Запуск юнит-тестов (с указанием сети:)
```
$ truffle test --network rinkeby
```

На данный момент тестами покрыта следующая функциональность:

* создания нескольких автономных сделок одновременно
* создания нескольких обычных сделок одновременно
* отслеживание событий (events) и логирование затрат на газ
