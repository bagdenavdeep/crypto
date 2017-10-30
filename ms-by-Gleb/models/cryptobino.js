'use strict'

var Web3 = require('web3');
var kvdb = require("../libs/db.js");
var fs = require("fs");

var restify = require('restify');
var restifyErrors = require('restify-errors');
var restifyErrorsOptions = require('restify-errors-options');
var restifyCorsMiddleware = require('restify-cors-middleware');

var validator = require('validator');
const uuidv4 = require('uuid/v4');
const uuidv1 = require('uuid/v1');

const cors = restifyCorsMiddleware({
	origins: ['*','null'],
	allowHeaders: ['Authorization'],
})

var cryptobinoAPI = function () {
	this.config = false;
	this.web3 = false;
	this.contract = false;
	this.db = false;
	this.logName = "[CryptoBino] ";
	
	this.init = function (_config, _extra) {
		this.config = _config;
		this.logName = this.logName+" ["+_extra.pid+"] ";
		this.initAPIserver();
		this.initWeb3();
		this.initDB();
	}
	
	this.initDB = function () {
		this.db = new kvdb();
		this.db.logName = this.logName+this.db.logName;
			this.db.init(this.config.redis);
	}

	this.initWeb3 = function () {
		this.web3 = new Web3(new Web3.providers.HttpProvider(this.config.web3.provider.host));
		// it;'s not clear do we need callback/wait, so may be bug will be there
		var tmp = JSON.parse(fs.readFileSync(this.config.contract.path, 'utf8'));	// TODO try/catch or callback
		this.contract = new this.web3.eth.Contract(tmp.abi, this.config.contract.address)
	}

	this.initAPIserver = function () {
		this.APIserver = restify.createServer({ name: this.config.name });
		restifyErrorsOptions.add('errors');
		//this.APIserver.pre(restify.pre.sanitizePath()); 
		this.APIserver.use(restify.plugins.fullResponse());
		this.APIserver.pre(cors.preflight);
		this.APIserver.use(cors.actual);
		if (this.config.gzip) this.APIserver.use(restify.plugins.gzipResponse());
		// limit (per second by ip) to prevent DDoS (http://restify.com/docs/plugins-api/)
		/*this.APIserver.use(restify.plugins.throttle({
			burst: 100,
			rate: 50,
			ip: true,
			overrides: {
				'192.168.1.1': {
					rate: 0,
					burst: 0
				}
			}
		}));*/
		this.APIserver.use(restify.plugins.bodyParser());
		//this.APIserver.use(restify.plugins.authorizationParser());
		this.APIserver.use(restify.plugins.queryParser());

		// methods
		this.APIserver.get("/test/success/", function (req, res, next) { 
			this.APItest(true, req, res, next) }.bind(this) 
		);
		this.APIserver.get("/test/fail/", function (req, res, next) { 
			this.APItest(false, req, res, next) }.bind(this) 
		);
		
		this.APIserver.post("/createWallet", function (req, res, next) { 
				this.API_createWallet(req, res, next) ;
			}.bind(this) 
		);
		
		this.APIserver.get("/getBalance", function (req, res, next) { 
				this.API_getBalance(req, res, next) ;
			}.bind(this) 
		);
		
		this.APIserver.post("/createDeal", function (req, res, next) { 
				this.API_createDeal(req, res, next) ;
			}.bind(this) 
		);

		this.APIserver.get("/getDealStatus", function (req, res, next) { 
				this.API_getDealStatus(req, res, next) ;
			}.bind(this) 
		);



		// error handler
		this.APIserver.on('restifyError', function (req, res, err, next) {
			// on restify error, custom answer
			err.toJSON = function customToJSON() { 
				return this._APIsend(false,{},{ code: err.body.code, message: err.body.message });
			}.bind(this);
			return next();
		}.bind(this));

		this.APIserver.listen(this.config.port, this.config.host, function() {
			global.log.info(this.logName, "server [",this.APIserver.name,"] at [",this.APIserver.url,"]");
		}.bind(this));

	}



	// methods
	this.API_createDeal = function (req, res, next) {
		// CHECK echo "address=0xe0Ed3E4134E8157aA840bCA712F8e7C877d0D631&amount=309.97&dealId=123456789&assetId=ETHUSD&dealType=1&profit=50&dealTime=1506502239&exprirationTime=1506502359" | curl -d @-  http://127.0.0.1:8888/createDeal
		// https://web3js.readthedocs.io/en/1.0/web3-eth-contract.html
		// https://github.com/ethereum/wiki/wiki/JavaScript-API#web3ethcontract
		// req.body.KEY
		// TODO check incomming data!
		//			??? _post.amount,
		var _post=req.body;
		this.contract.methods.createDeal(
			_post.dealId,
			_post.assetId,
			_post.dealType,
			_post.profit,
			_post.dealTime,
			_post.exprirationTime
			).call({from: _post.address}, 
				function (api_obj, err, result) {
					if (err == null) {
						console.log("RESULT", result);
						this.send(api_obj.req,api_obj.res,this._APIsend(true, '',false),api_obj.next());
					} else {
						console.log("ERROR", err);
						this.send(api_obj.req,api_obj.res,this._APIsend(false,false,{ code: 500, message: "method error" }),api_obj.next());
					}
				}.bind(this, { req: req, res: res, next: next })
			);		
	}

	this.API_getDealStatus = function (req, res, next) {
		// return error: Couldn't decode uint8 from ABI: 0x
		this.contract.methods.getDealStatus(
			req.query.dealId
			).call({}, 
				function (api_obj, err, result) {
					if (err == null) {
						console.log("RESULT", result);
						this.send(api_obj.req,api_obj.res,this._APIsend(true, result,false),api_obj.next());
					} else {
						console.log("ERROR", err);
						this.send(api_obj.req,api_obj.res,this._APIsend(false,false,{ code: 500, message: "method error" }),api_obj.next());
					}
				}.bind(this, { req: req, res: res, next: next })
			);		
	}
	
	this.API_getBalance = function (req, res, next) {
		// https://web3js.readthedocs.io/en/1.0/web3-eth.html#getbalance
		// TODO valid values
		this.web3.eth.getBalance(req.query.address,function (api_wallet, api_obj, err,result) {  
				if (err == null) {
					this.send(api_obj.req,api_obj.res,this._APIsend(true, {balance: result },false),api_obj.next());
				} else {
					this.send(api_obj.req,api_obj.res,this._APIsend(false,false,{ code: 404, message: "balance does not available" }),api_obj.next());
				}
			}.bind( this, { address: req.query.address }, { req: req, res: res, next: next }) 
		);
	}
	this.API_createWallet = function (req, res, next) {
		// TEST curl -d "" -X POST  http://127.0.0.1:8888/createWallet
		// https://web3js.readthedocs.io/en/1.0/web3-eth-accounts.html#create
		/*
			{ 
				address: '0xbCe9767B72A9Dc8468C161c74Bb55Cc738C2BEd8',
				privateKey: '0x0221281dfed86c7dd1ccd00f27a1d3bf0739b65294cbc4a904cd652921b2d28b',
				signTransaction: [Function: signTransaction],
				sign: [Function: sign],
				encrypt: [Function: encrypt] 
			}
		*/
		var wallet = this.web3.eth.accounts.create();
		// callback hell!
		this.db.set(wallet.address, wallet.privateKey, 
			function (api_wallet, api_obj, db_result) {
				if (db_result) {
					this.send(api_obj.req,api_obj.res,this._APIsend(true, api_wallet,false),api_obj.next());
				} else {
					this.send(api_obj.req,api_obj.res,this._APIsend(false,false,{ code: 500, message: "DB error" }),api_obj.next());
				}
			}.bind(this, { address: wallet.address }, { req: req, res: res, next: next })
		);
	}

	this.APItest = function (result, req, res, next) {
		// just demo
		var error=false;
		var r=false;
		if (result) {
			r="good";
		} else {
			error={code: 1, message: "test"}
		}
		this.send(req,res,this._APIsend(true,r,error),next());
	}


	this._APIsend = function (code, data, err) {
		// return JSON structure
		if (err==false) {
			if (data!='') {
				return {success: code, result: data};
			} else {
				return {success: code};
			}
		} else {
			return {success: code, error: {code: err.code, message: err.message}};
		}
	}

	this.send = function (req,res,v,_next) {
		res.send(v);
		_next;
	}

	this._ts = function () {
		return parseInt(new Date().getTime()/1000);
	}
	
	this._passwordHash = function(plaintext) {
		return crypto.createHash('sha1').update(plaintext).digest('hex');
	}


}

module.exports = cryptobinoAPI;
