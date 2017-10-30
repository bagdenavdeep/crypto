'use strict'

/*
    DB wrapper
    cache in redis
*/

var Redis = require('ioredis');

var kvdb = function () {
	this.config = false
	this.db = false;
	this.state = false;
	this.logName = "[KV] ";

	this.init = function (_dbconf) {
		this.config = {redis: _dbconf};
		this.initRedis();
	}


	this.initRedis = function () {
		this.db = new Redis();	// TODO redis config and handle errors!
		global.log.info(this.logName,"init Redis... TODO, error handler");
		this.state=true;
	}


	this.get = function (key, _callback) {
		// get from Redis
		global.log.info(this.logName,"[Redis] GET ["+key+"]");
		this.db.get(key, function (_cb, err, value) { 
			if (err){
				_cb(false);
			} else {
				_cb(value );
			}
			}.bind(this, _callback) 
		);
	}

	this.set = function (key, value, _callback) {
		// TODO callback and exceptions
		global.log.info(this.logName,"[Redis] SET ["+key+"]=["+value+"]");
		this.db.set(this.config.redis.prefix+":"+key, value);
		_callback(true);
	}
}

module.exports = kvdb;
