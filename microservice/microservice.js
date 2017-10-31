'use strict';

/* web3 */
var Web3 = require('web3');

/* web3-eth-personal */
var Personal = require('web3-eth-personal');

/* dbRedis */
var dbRedis = require('./db.js');

/* express */
var express = require('express');

/* express-validator */
var validator = require('express-validator');

/* body-parser */
var bodyParser = require('body-parser');

var microService = function () {

	this.db       = false;
	this.web3     = false;
	this.config   = false;
	this.personal = false;
	this.contract = false;

	this.init = function (config, logger) {
		this.config = config;
		this.logger = logger;
		this.initWeb3();
		this.initPersonal();
		this.initContract();
		this.initDB();
		this.initAPI();
	}

	this.getResponse = function(error, result) {

		let response = { success: false };

		if (error) {
			response['error'] = {
				'code': 0,
				'message': error
			}
		} else {
			response['success'] = true;
			response['result']  = result;
		}

		return response;
	}

	this.sendResponseError = function(error, res, req) {
		res.send(this.getResponse(error, null));
		this.logger.error(req.route.path, error);
	}

	this.getLastErrorMessage = function(errors) {
		return errors[errors.length - 1].msg;
	}

	this.isValidAddress = function(address, res) {

		let isAddress = this.web3.utils.isAddress(address);

		if (!isAddress) {
			res.send(this.getResponse("Error: invalid address", null));
		}
		return isAddress;
	}

	this.isValidationErrors = function(errors, res) {

		if (!errors.isEmpty()) {
			res.send(this.getResponse(this.getLastErrorMessage(errors.array()), null));
			return true;
		}

		return false;
	}

	this.initWeb3 = function () {
		this.web3 = new Web3(new Web3.providers.HttpProvider(this.config.get('web3Provider')));
		this.logger.info("Init web3");
	}

	this.initPersonal = function () {
		this.personal = new Personal(Personal.givenProvider || this.config.get('web3Provider'));
		this.logger.info("Init personal");
	}

	this.initContract = function () {
		let abi = this.config.get('contractABI');
		this.contract = new this.web3.eth.Contract(abi, this.config.get('contractAddress'));
		this.logger.info("Init contract");
	}

	this.initDB = function () {
		this.db = new dbRedis();
		this.db.init(this.config, this.logger);
	}

	this.initAPI = function () {

		let port = process.env.PORT;

		this.API = express();
		this.API.use(bodyParser.urlencoded({ extended: true }));
		this.API.use(validator());

		this.API.listen(port, function () {
			this.logger.info("API listen on %s", port);
		}.bind(this));

		const { check, validationResult } = require('express-validator/check');
		const {  matchedData, sanitize  } = require('express-validator/filter');

		this.API.get('/get_balance', (req, res) => {

			if (!this.isValidAddress(req.query.address, res)) {
				return;
			}

			try {
				this.web3.eth.getBalance(req.query.address, function (error, result) {

					if (error) {
						this.sendResponseError(error, res, req);
						return;
					}

					res.send(this.getResponse(error, {'result': this.web3.utils.fromWei(result, 'ether')} ));

				}.bind(this));
			} catch(e) {
				this.sendResponseError(e.message, res, req);
			}

		});

		this.API.get('/get_deal_status', [
			check('id').exists().isLength({min: 1}).withMessage('Error: id must be a string')
		], (req, res) => {

			if (this.isValidationErrors(validationResult(req), res)) {
				return;
			}

			try {
				this.contract.methods.getDealStatus(req.query.id).call({from: this.config.get('contractOwner')}, function(error, result) {

					if (error) {
						this.sendResponseError(error, res, req);
						return;
					}

					res.send(this.getResponse(error, {'result': result } ));

				}.bind(this));
			} catch(e) {
				this.sendResponseError(e.message, res, req);
			}

		});

		this.API.post('/create_deal', [
			check('address').exists().isLength({min: 1}).withMessage('Error: address doesn\'t exist'),
			check('amount').exists().isLength({min: 1}).isFloat().withMessage('Error: amount doesn\'t exist or not float'),
			check('id').exists().isLength({min: 1}).withMessage('Error: id doesn\'t exist'),
			check('asset').exists().isLength({min: 1}).withMessage('Error: asset doesn\'t exist or not letters'),
			check('trend').exists().isLength({min: 1}).isInt({min: 0, max: 2}).withMessage('Error: trend doesn\'t exist or not int'),
			check('payment_rate').exists().isLength({min: 1}).isInt({min: 0, max: 100}).withMessage('Error: payment_rate doesn\'t exist or not int'),
			check('created_at').exists().isLength({min: 1}).isInt().withMessage('Error: created_at doesn\'t exist or not int'),
			check('finished_at').exists().isLength({min: 1}).isInt().withMessage('Error: finished_at doesn\'t exist or not int')
		], (req, res) => {

			if (!this.isValidAddress(req.body.address, res)) {
				return;
			}

			if (this.isValidationErrors(validationResult(req), res)) {
				return;
			}

			try {

            	if (!this.db.status) {
					this.sendResponseError("Error: redis is not connecting", res, req);
					return;
				}

				this.db.methods.hget('addresses', req.body.address, function (redisError, redisResult) {

					if (!redisError) {

						let passphrase = redisResult;

						this.personal.unlockAccount(req.body.address, passphrase, this.config.get('unlockDuration'), function (error, result) {

							if (!error) {

								let transaction = {
									from: req.body.address,
									value: this.web3.utils.toWei(req.body.amount, 'ether'),
									// gasPrice: this.config.get("gasPrice"), // only mainnet
									gas: this.config.get('gasLimit')
								};

								this.contract.methods.createDeal(
									req.body.id,
									req.body.asset,
									req.body.trend,
									req.body.payment_rate,
									req.body.created_at,
									req.body.finished_at)
								.send(transaction)
								.on('transactionHash', function(hash) {
									res.send(this.getResponse(error, hash));
									this.logger.info(req.route.path, hash);
								}.bind(this))
								.on('error', function (e) {
									this.sendResponseError(e, res, req);
								}.bind(this));

								this.logger.info("%s unlock account %s", req.route.path, req.body.address);

							} else {
								res.send(this.getResponse("Error: could not decrypt key with given passphrase", null));
							}
						}.bind(this));
					} else {
						this.sendResponseError(redisError, res, req);
					}
				}.bind(this));

			} catch(e) {
				this.sendResponseError(e.message, res, req);
			}

		});

		this.API.post('/create_wallet', (req, res) => {

			try {

				if (!this.db.status) {
					this.sendResponseError("Error: redis is not connecting", res, req);
					return;
				}

				let passphrase = this.web3.utils.sha3(this.web3.utils.randomHex(32));

				this.personal.newAccount(passphrase, function (error, result) {

					if (!error) {
						this.db.methods.hset('addresses', result, passphrase, function (hsetError, hsetResult) {
							if (hsetResult) {
								this.logger.info("%s redis hset addresses %s", req.route.path, result);
								res.send(this.getResponse(error, {'result': result} ));
								this.logger.info(req.route.path, result);
							} else {
								this.sendResponseError(hsetError, res, req);
							}
						});
					} else {
						this.sendResponseError(error, res, req);
					}

				}.bind(this));

			} catch(e) {
				this.sendResponseError(e.message, res, req);
			}
		});

		this.logger.info("API Init");

	}

}

module.exports = microService;
