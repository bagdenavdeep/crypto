# Project CRYPTO microservice

Инструкция по установке и настройке компонент приведена для macOS. Чтобы использовать на других ОС, см. ссылки.

> Предварительно необходимо иметь задеплоенный контракт в сети Эфириум.

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

Переходим в папку с проектом и выполняем
```
$ npm install
```

### Forever
Для демонизации app.js запускаем
```
$ NODE_ENV=development forever start config/forever.json
```

Для остановки
```
$ NODE_ENV=development forever stopall
```

Проверить работоспособность можно [http://localhost:8000/getDealStatus?dealId=123](http://localhost:8000/getDealStatus?dealId=123)

Порт указан в папке `config` в файле с именем `NODE_ENV`, которое было указано при запуске `forever`
