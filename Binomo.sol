pragma solidity ^0.4.0;

import "./Oraclize.sol";

contract Binomo is usingOraclize
{
	event onError(string status, address indexed sender);
	event onSuccess(string status, address indexed sender);
	event onFinishDeal(string status, address indexed sender, uint predictedValue, uint realValue);
	event onChangeStatistics(uint totalDeals, uint totalWins, uint winRate, uint totalMoneyWon);

	uint public minInvested = 10000000000000000; // weis (0.01 ETH)
	uint public maxInvested = 50000000000000000; // weis (0.05 ETH)
	uint public bonusPay = 10; // percent of initial investment
	uint public nextRequestDelay = 60; // in seconds

	// TODO: заменить на реальное значение кошелька, куда выводятся проигрыши
	address brokerWallet = 0x8d06F9610C23Eb0bE6Eb3E3813f8497F4e8530b2;
	
	uint public totalDeals;
	uint public totalMoneyWon;
	uint public totalWins;
	uint public winRate;

	enum DealType { 
		Unknown,	// unknown value
		Call, 		// trader predics that price will increase (use '1' in API)
		Put   		// trader predics that price will decrease (use '2' in API)
	}

	struct Deal {
		address traderWallet;		// address of trader's wallet
		uint amount;				// amount of tokens that trader has invested in deal
		DealType dealType;			// type of deal: CALL / PUT
		string assetId;				// asset id to use in request to oracle
		bytes32 firstQueryId;		// id of 1st async query to oracle
		bytes32 secondQueryId;		// id of 2nd async query to oracle
		uint firstQueryResult;		// result of 1st query
		uint secondQueryResult;		// result of 2nd query
		uint256 dealTime;			// time when trader made an investment (UNIXTIME)
		uint256 expirationTime;		// expiration time (UNIXTIME)
		bool isAutonomous;			// true, when deal was initiated by transferring tokens to the contract
	}

	mapping (bytes32 => Deal) deals;
	

	modifier ownerOnly() {
		require(msg.sender == owner);
		_;
	}

	function () payable {
		require(msg.sender != owner);
		createAutonomousDeal();
	}

	address owner;

	function Binomo() payable {
		owner = msg.sender;
	}

	function createAutonomousDeal() payable {

		if (msg.value > maxInvested || msg.value < minInvested) {
			onError("Investment amount out of acceptable range", msg.sender);
			// msg.sender.transfer(msg.value - 2000);
		} else {
			onSuccess("Payment received", msg.sender);

			string memory url = "json(https://min-api.cryptocompare.com/data/price?fsym=ETH&tsyms=USD).USD";
			bytes32 queryId = oraclize_query("URL", url);

			deals[queryId] = Deal({
				traderWallet: msg.sender,
				amount: msg.value,
				dealType: DealType.Call, // TODO: придумать как задавать разные значения
				assetId: "ETHUSD", // TODO: фиксированный торговый идентификатор актива (для урла)
				firstQueryId: queryId,
				secondQueryId: bytes32(0),
				firstQueryResult: 0,
				secondQueryResult: 0,
				dealTime: now, // using current time of node (WARN: can be manipulated be node owner)
				expirationTime: 0,
				isAutonomous: true
			});
		}
	}

	function createDeal(string assetId, uint dealTypeInt, uint256 dealTime, uint256 expirationTime) ownerOnly payable {

		if (msg.value > maxInvested || msg.value < minInvested) {
			onError("Investment amount out of acceptable range", msg.sender);
			// msg.sender.transfer(amount - 2000);
		} else {

			DealType dealType = dealTypeUintToEnum(dealTypeInt);
			require(dealType != DealType.Unknown);

			onSuccess("Payment received", msg.sender);

			string memory url = strConcat("json(https://min-api.cryptocompare.com/data/pricehistorical?fsym=ETH&tsyms=USD&ts=", uint2str(dealTime), ").ETH.USD");
			bytes32 queryId = oraclize_query("URL", url);

			deals[queryId] = Deal({
				traderWallet: msg.sender,
				amount: msg.value,
				dealType: dealType,
				assetId: assetId,
				firstQueryId: queryId,
				secondQueryId: bytes32(0),
				firstQueryResult: 0,
				secondQueryResult: 0,
				dealTime: dealTime,
				expirationTime: expirationTime,
				isAutonomous: false
			});
		}
	}

	function __callback(bytes32 queryId, string result) {

		require(msg.sender == oraclize_cbAddress());

		Deal memory currentDeal = deals[queryId];

		if (currentDeal.firstQueryId == queryId && currentDeal.secondQueryId == 0) {

			string memory url;
			bytes32 secondQueryId;

			if (currentDeal.isAutonomous) {
				url = "json(https://min-api.cryptocompare.com/data/price?fsym=ETH&tsyms=USD).USD";
				secondQueryId = oraclize_query(nextRequestDelay, "URL", url);
			} else {
				uint delay = currentDeal.expirationTime - currentDeal.dealTime;
				url = strConcat("json(https://min-api.cryptocompare.com/data/pricehistorical?fsym=ETH&tsyms=USD&ts=", uint2str(currentDeal.expirationTime), ").ETH.USD");
				secondQueryId = oraclize_query(delay, "URL", url);
			}

			// create deal for 2nd request coping 1st one
			deals[queryId] = Deal({
				traderWallet: currentDeal.traderWallet,
				amount: currentDeal.amount,
				dealType: currentDeal.dealType,
				assetId: currentDeal.assetId,
				firstQueryId: bytes32(0),
				secondQueryId: secondQueryId,
				firstQueryResult: stringToUint(result),
				secondQueryResult: 0,
				dealTime: currentDeal.dealTime,
				expirationTime: currentDeal.expirationTime,
				isAutonomous: currentDeal.isAutonomous
			});

		} else if (currentDeal.firstQueryId == 0 && currentDeal.secondQueryId == queryId) {

			currentDeal.secondQueryResult = stringToUint(result);

			if (currentDeal.firstQueryResult > currentDeal.secondQueryResult) {
				if (DealType.Call == currentDeal.dealType) {
					investmentFails(queryId);
				} else if (DealType.Put == currentDeal.dealType) {
					investmentSucceed(queryId);
				}
			} else if (currentDeal.firstQueryResult < currentDeal.secondQueryResult) {
				if (DealType.Call == currentDeal.dealType) {
					investmentSucceed(queryId);
				} else if (DealType.Put == currentDeal.dealType) {
					investmentFails(queryId);
				}
			} else if (currentDeal.firstQueryResult == currentDeal.secondQueryResult) {
				// TODO: узнать у Паши, какое мин. отклонение от исходного значения считается "равенством"
				investmentReturns(queryId);
			}
		}
	}

	function investmentSucceed(bytes32 queryId) private {

		Deal memory deal = deals[queryId];

		totalDeals++;
		totalWins++;
		winRate = totalWins * 100 / totalDeals;
		
		uint amountWon = (deal.amount * (100 + bonusPay)) / 100;
		totalMoneyWon = totalMoneyWon + amountWon;
		
		deal.traderWallet.transfer(amountWon);

		onFinishDeal("Investment succeed", deal.traderWallet, deal.firstQueryResult, deal.secondQueryResult);
		onChangeStatistics(totalDeals, totalWins, winRate, totalMoneyWon);
	}

	function investmentFails(bytes32 queryId) private {

		Deal memory deal = deals[queryId];

		totalDeals++;
		winRate = totalWins * 100 / totalDeals;

		//deal.traderWallet.transfer(1); -- not sure we should transfer money on fail
		brokerWallet.transfer(deal.amount);

		onFinishDeal("Investment fails", deal.traderWallet, deal.firstQueryResult, deal.secondQueryResult);
		onChangeStatistics(totalDeals, totalWins, winRate, totalMoneyWon);
	}

	function investmentReturns(bytes32 queryId) private {

		Deal memory deal = deals[queryId];

		totalDeals++;
		winRate = totalWins * 100 / totalDeals;

		deal.traderWallet.transfer(deal.amount);

		onFinishDeal("Investment returns", deal.traderWallet, deal.firstQueryResult, deal.secondQueryResult);
		onChangeStatistics(totalDeals, totalWins, winRate, totalMoneyWon);
	}
/*
	function drainBalance() payable ownerOnly {
		owner.transfer(this.balance);
	}
*/
	function setMinInvested(uint _value) ownerOnly {
		minInvested = _value;
	}

	function setMaxInvested(uint _value) ownerOnly {
		maxInvested = _value;
	}

	function setBonusPay(uint _value) ownerOnly {
		bonusPay = _value;
	}

	function setNextRequestDelay(uint _value) ownerOnly {
		nextRequestDelay = _value;
	}

	function setBrokerWallet(address _value) ownerOnly {
		brokerWallet = _value;
	}

	function dealTypeUintToEnum(uint value) private returns(DealType) {
		if (value == 1) {
			return DealType.Call;
		} else if (value == 2) {
			return DealType.Put;
		}
		return DealType.Unknown;
	}

	function stringToUint(string s) private returns (uint) {
		bytes memory b = bytes(s);
		uint i;
		uint result1 = 0;
		for (i = 0; i < b.length; i++) {
			uint c = uint(b[i]);
			if (c == 46) {
				// nop
			} else if (c >= 48 && c <= 57) {
				result1 = result1 * 10 + (c - 48);
			}
		}

		if (result1 < 10000) {
			result1 = result1 * 100;
			return result1;
		} else if (result1 < 100000) {
			result1 = result1 * 10;
			return result1;
		} else {
			return result1;
		}
	}
}
