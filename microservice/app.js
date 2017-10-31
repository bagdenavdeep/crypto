'use strict';

const cluster = require('cluster');
const doThreads = require('os').cpus().length * 2;	// number of threads depends on CPUs

/* config */
var config = require('config');

/* log4js */
var log4js = require('log4js');

/* microservice */
var microService = require('./microservice');

if (cluster.isMaster) {

	var pid = process.pid.toString();
	var logger = log4js.getLogger(pid);
	logger.level = config.get('loggerLevel');

	var watchdogTimer = false;

	function respawn() {
		cluster.fork();
	}

	function watchdog () {
		if (Object.keys(cluster.workers).length < doThreads) {
			logger.info("Watchdog respawn process");
			respawn();
		}
	}

	function messageHandler(w, msg) {
		// reseive messages from workers/slaves
		if (msg.cmd && msg.cmd === "set") {}
		if (msg.cmd && msg.cmd === "get") {}
	}

	logger.info("Master start pid = %s", process.pid);
	cluster.on('message', messageHandler);
	watchdogTimer = setInterval (watchdog, 400);	// recheck processes and respawn in as soon as they died

} else {

	var pid = process.pid.toString();
	var logger = log4js.getLogger(pid);
	logger.level = config.get("loggerLevel");
	logger.info("Worker start pid = %s", pid);

	var API = new microService();
	API.init(config, logger);

	process.on("message", function (msg) {
		// reseive messages from master
		if (msg.cmd == "close") {
			//API._processClose();
		}
	});

}
