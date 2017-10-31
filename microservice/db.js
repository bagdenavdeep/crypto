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

		this.methods.on("error", function(error) {
			logger.error("Redis is not connecting");
			logger.error(error);
			this.status = false;
		}.bind(this));

		this.methods.on("connect", function() {
			logger.info("Redis is connecting");
			this.status = true;
		}.bind(this));

	}

}

module.exports = dbRedis;
	
