'use strict';

var Redis = require('ioredis');

var dbRedis = function () {

	this.db     = false;
	this.config = false;
	this.status = false;

	this.init = function (config, logger) {

		let redisConfig = {
			host: config.get('redisHost'),
			port: config.get('redisPort'),
			password: config.get('redisPassword')
		};

		this.methods = new Redis(redisConfig);

		if (this.methods.status == "connecting") {
			this.status = true;
			logger.info("Redis is connecting");
		} else {
			logger.error("Redis is not connecting");
		}

	}

}

module.exports = dbRedis;
