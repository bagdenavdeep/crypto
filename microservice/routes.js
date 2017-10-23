var Web3     = require('web3');
var config   = require('config');
var log4js   = require('log4js');
var logger   = log4js.getLogger();
logger.level = config.get("loggerLevel");

var web3;
if (typeof web3 !== 'undefined') {
    web3 = new Web3(web3.currentProvider);
} else {
    web3 = new Web3(new Web3.providers.HttpProvider(config.get('web3Provider')));
}

var Personal = require('web3-eth-personal');
var personal = new Personal(Personal.givenProvider || config.get('web3Provider'));

var abi = config.get('contractABI');

var contract = new web3.eth.Contract(abi, config.get('contractAddress'));

function getResponse(error, result) {

	var response = { success: false };

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

function getLastErrorMessage(errors) {
	return errors[errors.length - 1].msg;
}

function isValidAddress(address, res) {
	var isAddress = web3.utils.isAddress(address);
	if (!isAddress) {
		res.send(getResponse("Error: invalid address", null));
	}
	return isAddress;
}

function isValidationErrors(errors, res) {
	if (!errors.isEmpty()) {
		res.send(getResponse(getLastErrorMessage(errors.array()), null));
		return true;
	}
	return false;
}

module.exports = function(app) {

	const { check, validationResult } = require('express-validator/check');
	const { matchedData, sanitize }   = require('express-validator/filter');

	var getBalance = 'getBalance';
	app.get('/' + getBalance, (req, res) => {

		if (!isValidAddress(req.query.address, res)) {
			return;
		}

		try {
			web3.eth.getBalance(req.query.address, function (error, result) {
				res.send(getResponse(error, {'result': web3.utils.toWei(result, "ether")} ));
			});
		} catch(e) {
			res.send(getResponse(e.message, null));
			logger.error(getBalance + " " + e.message);
		}

	});

	var getDealStatus = 'getDealStatus';
	app.get('/' + getDealStatus, [
		check('dealId').exists().isLength({min: 1}).withMessage('Error: dealId must be an string')
	], (req, res) => {

		if (isValidationErrors(validationResult(req), res)) {
			return;
		}

		try {
			contract.methods.getDealStatus(req.query.dealId).call({from: config.get('contractOwner')}, function(error, result) {
				res.send(getResponse(error, {'result': result } ));
			});
		} catch(e) {
			res.send(getResponse(e.message, null));
			logger.error(getDealStatus + " " + e.message);
		}

	});

	var createDeal = 'createDeal';
	app.post('/' + createDeal, [
		check('address').exists().isLength({min: 1}).withMessage('Error: address doesn\'t exist'),
		check('amount').exists().isLength({min: 1}).isFloat().withMessage('Error: amount doesn\'t exist or not float'),
		check('dealId').exists().isLength({min: 1}).withMessage('Error: dealId doesn\'t exist'),
		check('assetId').exists().isLength({min: 1}).isAlpha().withMessage('Error: assetId doesn\'t exist or not letters'),
		check('dealType').exists().isLength({min: 1}).isInt({min: 0, max: 4}).withMessage('Error: dealType doesn\'t exist or not int'),
		check('profit').exists().isLength({min: 1}).isInt({min: 0, max: 100}).withMessage('Error: profit doesn\'t exist or not int'),
		check('dealTime').exists().isLength({min: 1}).isInt().withMessage('Error: dealTime doesn\'t exist or not int'),
		check('exprirationTime').exists().isLength({min: 1}).isInt().withMessage('Error: exprirationTime doesn\'t exist or not int')
	], (req, res) => {

		if (!isValidAddress(req.body.address, res)) {
			return;
		}

		if (isValidationErrors(validationResult(req), res)) {
			return;
		}

		try {

			let passphrase = '0x2538cc0060d79425486c599607c48906000d27fa0aed785798f5a4f52afabb9f';
			// TODO get passphrase from DB

			personal.unlockAccount(req.body.address, passphrase, 1, function (error, result) {

				if (!error) {

					let transaction = {
						from: req.body.address,
						value: web3.utils.toWei(req.body.amount, "ether"),
						// gasPrice: config.get("gasPrice"), // only mainnet
						gas: config.get("gasLimit")
					};

					contract.methods.createDeal(
						req.body.dealId,
						req.body.assetId,
						req.body.dealType,
						req.body.profit,
						req.body.dealTime,
						req.body.exprirationTime)
					.send(transaction)
					.on('transactionHash', function(hash) {
						res.send(getResponse(error, hash));
						logger.info(createDeal + " " + hash);
					})
					.on('error', function (e) {
						res.send(getResponse(e, null));
						logger.error(createDeal + " " + e);
					});

					logger.info(createDeal + " unlock account " + req.body.address);

				} else {
					res.send(getResponse(createDeal + " Error: could not decrypt key with given passphrase", null));
				}
			});

		} catch(e) {
			res.send(getResponse(createDeal + " " + e.message, null));
		}

	});

	var createWallet = 'createWallet';
	app.post('/' + createWallet, (req, res) => {

		try {

			let passphrase = web3.utils.sha3(web3.utils.randomHex(32));
			// TODO save passphrase to DB

			personal.newAccount(passphrase, function (error, result) {

				if (!error) {
					res.send(getResponse(error, {'result': result} ));
					logger.info("createWallet " + result, passphrase);
				} else {
					res.send(getResponse(error, null));
					logger.error("createWallet " + error);
				}

			});

		} catch(e) {
			res.send(getResponse(e.message, null));
			logger.error(createWallet + " " + e.message);
		}
	});

};
