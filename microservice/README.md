# Project CRYPTO microservice

Инструкция по установке и настройке компонент приведена для macOS. Чтобы использовать на других ОС, см. ссылки.

> Предварительно необходимо иметь опубликованный контракт в сети Эфириум. Команду для публикации можно найти [здесь](https://github.com/BinomoTech/crypto/tree/master/contracts)

## Homebrew
Устанавливаем менеджер пакетов Homebrew. Он потребуется для установки последующих компонент.
```
$ /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
```

Доп. инф: https://brew.sh/

## Redis
Устанавливаем redis
```
$ brew install redis
```

Запускаем redis
```
$ redis-server /usr/local/etc/redis.conf
```

Доп. инф: https://redis.io/download

## Geth
Для работоспособности сервиса необходима локальная нода Эфириума [geth](https://github.com/ethereum/go-ethereum/wiki/geth)
```
$ brew tap ethereum/ethereum
$ brew install ethereum
```

### Run
Запускаем geth для работы с rinkeby
```
$ geth --rinkeby --rpc --rpcaddr localhost --rpcport 8545 --rpcapi=personal,eth,web3 --fast --cache=1024
```

### Remove DB
Полезная команда для удаления локального блокчейна:
```
$ geth removedb --datadir=/$HOME/Library/Ethereum/rinkeby
```

## NodeJS
Устанавливаем nodejs
```
$ brew install node
```

Доп. инф: https://nodejs.org/en/

Переходим в папку с заранее склонированным проектом и выполняем
```
$ npm install
```

### Forever
Устанавливаем forever
```
$ npm install forever -g
```

Для демонизации app.js запускаем
```
$ PORT=8000 NODE_ENV=development forever start config/forever.json
```

Для остановки
```
$ PORT=8000 NODE_ENV=development forever stopall
```

Проверить работоспособность можно [http://localhost:8000/get_deal_status?id=123](http://localhost:8000/get_deal_status?id=123)
