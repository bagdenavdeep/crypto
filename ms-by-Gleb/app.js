"use strict";

const cluster = require('cluster');
const doThreads = require('os').cpus().length;	// number of threads depends on CPUs


const SimpleNodeLogger = require('simple-node-logger'),
	opts = {
		timestampFormat:'YYYY-MM-DD HH:mm:ss.SSS'
	};
	global.log = SimpleNodeLogger.createSimpleLogger( opts );
	global.log.setLevel('all');


var config = require("./config/config");
var _cryptobinoAPI = require(config.API.path);

/*
> personal.newAccount("12345");
"0x897eb3053465e4312e275d7b46d32658bd31f04d"
*/


if (cluster.isMaster) {

	var watchdog_timer = false;
	function respawn() {
		cluster.fork();
	}


	function watchdog () {
		if (Object.keys(cluster.workers).length<doThreads) {
			global.log.warn("[Watchdog] ", "respawn process");
			respawn();
		}
	}

	function messageHandler(w, msg) {
		// reseive messages from workers/slaves
		if (msg.cmd && msg.cmd === 'set') {
		}
		if (msg.cmd && msg.cmd === 'get') {			
		}
	}
	
	
	
	global.log.info("[Master] ", "Start PID=", process.pid);
	cluster.on('message', messageHandler);
	watchdog_timer = setInterval (watchdog, 400);	// recheck processes and respawn in as soon as they died
} else {
	var API = new _cryptobinoAPI();
	API.init(config.API, {pid: process.pid});
	global.log.debug("[Worker] ", "[Start] PID=", process.pid);
	process.on('message', function (msg) {
		// reseive messages from master
		if (msg.cmd=='close') {
			//API._processClose();
		}
	}
);

}
