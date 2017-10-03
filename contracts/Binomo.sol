pragma solidity ^0.4.0;

import "./UsingOraclize.sol";

contract Binomo is UsingOraclize
{
	event onError(string status, address indexed sender);
	event onSuccess(string status, address indexed sender, uint amount);
	event onFinishDeal(string status, address indexed sender, uint predictedValue, uint realValue);
	event onChangeStatistics(uint totalDeals, uint totalWins, uint winRate, uint totalMoneyWon);
	event onGetResult(string status, string result);

	uint public minAmount = 0.01 ether;
	uint public maxAmount = 0.05 ether;
	uint public defaultProfit = 10; // profit for autonomous deals (percent of deal)
	uint public defaultDuration = 60; // duration of autonomous deals (in seconds)
	string public defaultAssetId = "ETHUSD";

	uint public totalDeals = 0;
	uint public totalMoneyWon = 0;
	uint public totalWins = 0;
	uint public winRate = 0;

	uint private gasPrice = 0.004 szabo;
	uint private gasLimitFirstQuery  = 400000;
	uint private gasLimitSecondQuery = 200000;

	enum DealStatus {
		Finished,
		WaitingFirstResult,
		WaitingSecondResult,
		Processing,
		UnknownDealId
	}

	enum DealType {
		Unknown,	// unknown value
		Call, 		// trader predics that price will increase (use '1' in API)
		Put   		// trader predics that price will decrease (use '2' in API)
	}

	struct Deal {
		string dealId;
		address traderWallet;		// address of trader's wallet
		uint amount;				// amount of tokens that trader has invested in deal
		uint profit;				// percent of initial investment
		DealType dealType;			// type of deal: CALL / PUT
		string assetId;				// asset id to use in request to oracle
		bytes32 firstQueryId;		// id of 1st async query to oracle
		bytes32 secondQueryId;		// id of 2nd async query to oracle
		uint firstQueryResult;		// result of 1st query
		uint secondQueryResult;		// result of 2nd query
		uint dealTime;				// time when trader made an investment (UNIXTIME)
		uint expirationTime;		// expiration time (UNIXTIME)
		uint duration;				// delay to 2nd request to oracle
	}

	mapping (bytes32 => Deal) deals;
	mapping (string => bytes32) dealIdentifiers;

	modifier ownerOnly() {
		require(msg.sender == owner);
		_;
	}

	function () payable {
		require(msg.sender != owner);
		createAutonomousDeal();
	}

	address owner = 0;

	function Binomo() payable {
		owner = msg.sender;
	}

	function getDealStatus(string dealId) ownerOnly constant returns(DealStatus) {

		require(bytes(dealId).length > 0);

		bytes32 queryId = dealIdentifiers[dealId];
		if (bytes32(0) == queryId) {
			return DealStatus.UnknownDealId;
		}
		Deal memory deal = deals[queryId];
		if (bytes32(0) != deal.firstQueryId) {
			return DealStatus.WaitingFirstResult;
		}
		if (bytes32(0) != deal.secondQueryId) {
			if (0 == deal.secondQueryResult) {
				return DealStatus.WaitingSecondResult;	
			}
			return DealStatus.Finished;
		}
		return DealStatus.Processing;
	}

	function createAutonomousDeal() payable {

		if (msg.value > maxAmount || msg.value < minAmount) {
			onError("Amount out of acceptable range", msg.sender);
			// msg.sender.transfer(msg.value - 2000);
		} else {

			onSuccess("Payment received", msg.sender, msg.value);

			/*uint predictedProfit = computeDealProfit(msg.value, defaultProfit);*/
			/*require(this.balance > predictedProfit);*/
			// TODO: make sure that balance is enough for all registered deals

			uint256 dealTime = now; // current time of node (WARN: can be manipulated be node owner)
			uint256 expirationTime = dealTime + defaultDuration;
			string memory assetId = defaultAssetId;

			oraclize_setCustomGasPrice(gasPrice);

			string memory url = buildOracleURL(assetId, dealTime);
			bytes32 firstQueryId = oraclize_query("URL", url, gasLimitFirstQuery);

			string memory dealId = "fixed-deal-identifier";

			deals[firstQueryId] = Deal({
				dealId: dealId,
				traderWallet: msg.sender,
				amount: msg.value,
				profit: defaultProfit,
				dealType: DealType.Call,
				assetId: assetId,
				firstQueryId: firstQueryId,
				secondQueryId: 0,
				firstQueryResult: 0,
				secondQueryResult: 0,
				dealTime: dealTime,
				expirationTime: expirationTime,
				duration: (expirationTime - dealTime)
			});

			dealIdentifiers[dealId] = firstQueryId;
		}
	}

	function createDeal(string _dealId, string _assetId, uint _dealTypeInt, uint _profit, uint256 _dealTime, uint256 _expirationTime) payable {

		if (msg.value > maxAmount || msg.value < minAmount) {
			onError("Amount out of acceptable range", msg.sender);
			// msg.sender.transfer(amount - 2000);
		} else {

			onSuccess("Payment received", msg.sender, msg.value);

			/*uint predictedProfit = computeDealProfit(msg.value, _profit);*/
			/*require(this.balance > predictedProfit);*/
			// TODO: make sure that balance is enough for all registered deals

			require(bytes(_dealId).length > 0);

			DealType dealType = dealTypeUintToEnum(_dealTypeInt);
			require(dealType != DealType.Unknown);

			require(_dealTime > 0);
			require(_expirationTime > _dealTime);

			oraclize_setCustomGasPrice(gasPrice);

			string memory url = buildOracleURL(_assetId, _dealTime);
			bytes32 firstQueryId = oraclize_query("URL", url, gasLimitFirstQuery);

			deals[firstQueryId] = Deal({
				dealId: _dealId,
				traderWallet: msg.sender,
				amount: msg.value,
				profit: _profit,
				dealType: dealType,
				assetId: _assetId,
				firstQueryId: firstQueryId,
				secondQueryId: 0,
				firstQueryResult: 0,
				secondQueryResult: 0,
				dealTime: _dealTime,
				expirationTime: _expirationTime,
				duration: (_expirationTime - _dealTime)
			});

			dealIdentifiers[_dealId] = firstQueryId;
		}
	}

	function buildOracleURL(string /*_assetId*/, uint256 _time) private constant returns (string) {
		// TODO: use assetId in URL
		// TODO: use Binomo oracle
		return strConcat("json(https://min-api.cryptocompare.com/data/pricehistorical?fsym=ETH&tsyms=USD&ts=", uint2str(_time), ").ETH.USD");
	}

	function __callback(bytes32 selfId, string selfResult) {

		require(selfId != bytes32(0));
		require(msg.sender == oraclize_cbAddress());

		Deal memory deal = deals[selfId];
		require(deal.dealType != DealType.Unknown);

		if (deal.firstQueryId == selfId && deal.secondQueryId == 0) {

			uint firstQueryResult = stringToUint(selfResult);
			deals[selfId].firstQueryResult = firstQueryResult;

			string memory url = buildOracleURL(deal.assetId, deal.expirationTime);
			bytes32 secondQueryId = oraclize_query(deal.duration, "URL", url, gasLimitSecondQuery);

			// create deal for 2nd request coping 1st one
			deals[secondQueryId] = Deal({
				dealId: deal.dealId,
				traderWallet: deal.traderWallet,
				amount: deal.amount,
				profit: deal.profit,
				dealType: deal.dealType,
				assetId: deal.assetId,
				firstQueryId: 0,
				secondQueryId: secondQueryId,
				firstQueryResult: firstQueryResult,
				secondQueryResult: 0,
				dealTime: deal.dealTime,
				expirationTime: deal.expirationTime,
				duration: deal.duration
			});

			dealIdentifiers[deal.dealId] = secondQueryId;
			
			onGetResult("Got first result", selfResult);
		}
		else if (deal.firstQueryId == 0 && deal.secondQueryId == selfId) {

			uint secondQueryResult = stringToUint(selfResult);
			deal.secondQueryResult = secondQueryResult;
			deals[selfId].secondQueryResult = secondQueryResult;

			if (deal.firstQueryResult > deal.secondQueryResult) {
				if (DealType.Call == deal.dealType) {
					investmentFails(deal);
				} else if (DealType.Put == deal.dealType) {
					investmentSucceed(deal);
				}
			} else if (deal.firstQueryResult < deal.secondQueryResult) {
				if (DealType.Call == deal.dealType) {
					investmentSucceed(deal);
				} else if (DealType.Put == deal.dealType) {
					investmentFails(deal);
				}
			} else if (deal.firstQueryResult == deal.secondQueryResult) {
				investmentReturns(deal);
			}

			onGetResult("Got second result", selfResult);
		}
	}

	function investmentSucceed(Deal deal) private {

		totalDeals++;
		totalWins++;
		winRate = totalWins * 100 / totalDeals;

		uint amountWon = computeDealProfit(deal.amount, deal.profit);
		totalMoneyWon += amountWon;

		/*deal.traderWallet.transfer(amountWon);*/

		onFinishDeal("Investment succeed", deal.traderWallet, deal.firstQueryResult, deal.secondQueryResult);
		onChangeStatistics(totalDeals, totalWins, winRate, totalMoneyWon);
	}

	function investmentFails(Deal deal) private {

		totalDeals++;
		winRate = totalWins * 100 / totalDeals;

		// TODO: обсудить с Никитой: куда уходят деньги проигравшей сделки
		// сейчас проигравшие сделки остаются на балансе смарт-контракта
		/*deal.traderWallet.transfer(1); //-- not sure we should transfer money on fail*/

		onFinishDeal("Investment fails", deal.traderWallet, deal.firstQueryResult, deal.secondQueryResult);
		onChangeStatistics(totalDeals, totalWins, winRate, totalMoneyWon);
	}

	function investmentReturns(Deal deal) private {

		totalDeals++;
		winRate = totalWins * 100 / totalDeals;

		/*deal.traderWallet.transfer(deal.amount);*/

		onFinishDeal("Investment returns", deal.traderWallet, deal.firstQueryResult, deal.secondQueryResult);
		onChangeStatistics(totalDeals, totalWins, winRate, totalMoneyWon);
	}

	function computeDealProfit(uint amount, uint profit) private constant returns (uint) {
		return (amount * (100 + profit)) / 100;
	}

	function withdrawBalance() payable ownerOnly {
		owner.transfer(this.balance);
	}

	function setMinAmount(uint _value) ownerOnly {
		minAmount = _value;
	}

	function setMaxAmount(uint _value) ownerOnly {
		maxAmount = _value;
	}

	function setDefaultProfit(uint _value) ownerOnly {
		defaultProfit = _value;
	}

	function setDefaultDuration(uint _value) ownerOnly {
		defaultDuration = _value;
	}

	function dealTypeUintToEnum(uint value) private constant returns (DealType) {
		if (value == 1) {
			return DealType.Call;
		} else if (value == 2) {
			return DealType.Put;
		}
		return DealType.Unknown;
	}

	function stringToUint(string s) constant returns (uint) {
		bytes memory b = bytes(s);
		uint result = 0;
		bool onFraction = false;
		uint FractionMultiplier = 100; // fixed number of digits after comma (100 means 2 digits)
		uint fractionMultiplier = FractionMultiplier;
		for (uint i = 0; i < b.length; i++) {
			uint c = uint(b[i]);
			if (c == 46) {
				onFraction = true;
				result *= fractionMultiplier;
				fractionMultiplier /= 10;
			} else if (c >= 48 && c <= 57) {
				if (onFraction) {
					result += (c - 48) * fractionMultiplier;
					fractionMultiplier /= 10;
				} else {
					result *= 10;
					result += (c - 48);
				}
			}
			if (onFraction && 0 == fractionMultiplier) {
				break; // fraction length limit is reached
			}
		}
		if (!onFraction) {
			result *= FractionMultiplier;
		}
		return result;
	}
}
