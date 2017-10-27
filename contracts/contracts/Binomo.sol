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
	uint public defaultPaymentRate = 10; // payment rate for autonomous deals (percent of deal)
	uint public defaultDuration = 60; // duration of autonomous deals (in seconds)
	string public defaultAsset = "ETHUSD";

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

	enum Trend {
		Unknown,	// unknown value
		Call, 		// trader predics that price will increase (use '1' in API)
		Put   		// trader predics that price will decrease (use '2' in API)
	}

	struct Deal {
		string id;
		address traderWallet;		// address of trader's wallet
		uint amount;				// amount of tokens that trader has invested in deal
		uint paymentRate;           // percent of initial investment
		Trend trend;			    // type of deal: CALL / PUT
		string asset;				// asset id to use in request to oracle
		bytes32 firstQueryId;		// id of 1st async query to oracle
		bytes32 secondQueryId;		// id of 2nd async query to oracle
		uint firstQueryResult;		// result of 1st query
		uint secondQueryResult;		// result of 2nd query
		uint createdAt;				// time when trader made an investment (UNIXTIME)
		uint finishedAt;            // expiration time (UNIXTIME)
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

			/*uint predictedPaymentRate = computeDealPaymentRate(msg.value, defaultPaymentRate);*/
			/*require(this.balance > predictedPaymentRate);*/
			// TODO: make sure that balance is enough for all registered deals

			uint256 createdAt = now; // current time of node (WARN: can be manipulated be node owner)
			uint256 finishedAt = createdAt + defaultDuration;
			string memory asset = defaultAsset;

			oraclize_setCustomGasPrice(gasPrice);

			string memory url = buildOracleURL(asset, createdAt);
			bytes32 firstQueryId = oraclize_query("URL", url, gasLimitFirstQuery);

			string memory id = "fixed-deal-identifier";

			deals[firstQueryId] = Deal({
				id: id,
				traderWallet: msg.sender,
				amount: msg.value,
				paymentRate: defaultPaymentRate,
				trend: Trend.Call,
				asset: asset,
				firstQueryId: firstQueryId,
				secondQueryId: 0,
				firstQueryResult: 0,
				secondQueryResult: 0,
				createdAt: createdAt,
				finishedAt: finishedAt,
				duration: (finishedAt - createdAt)
			});

			dealIdentifiers[id] = firstQueryId;
		}
	}

	function createDeal(string _id, string _asset, uint _trend, uint _paymentRate, uint256 _createdAt, uint256 _finishedAt) payable {

		if (msg.value > maxAmount || msg.value < minAmount) {
			onError("Amount out of acceptable range", msg.sender);
			// msg.sender.transfer(amount - 2000);
		} else {

			onSuccess("Payment received", msg.sender, msg.value);

			/*uint predictedPaymentRate = computeDealPaymentRate(msg.value, _paymentRate);*/
			/*require(this.balance > predictedPaymentRate);*/
			// TODO: make sure that balance is enough for all registered deals

			require(bytes(_id).length > 0);

			Trend trend = trendUintToEnum(_trend);
			require(trend != Trend.Unknown);

			require(_createdAt > 0);
			require(_finishedAt > _createdAt);

			oraclize_setCustomGasPrice(gasPrice);

			string memory url = buildOracleURL(_asset, _createdAt);
			bytes32 firstQueryId = oraclize_query("URL", url, gasLimitFirstQuery);

			deals[firstQueryId] = Deal({
				id: _id,
				traderWallet: msg.sender,
				amount: msg.value,
				paymentRate: _paymentRate,
				trend: trend,
				asset: _asset,
				firstQueryId: firstQueryId,
				secondQueryId: 0,
				firstQueryResult: 0,
				secondQueryResult: 0,
				createdAt: _createdAt,
				finishedAt: _finishedAt,
				duration: (_finishedAt - _createdAt)
			});

			dealIdentifiers[_id] = firstQueryId;
		}
	}

	function buildOracleURL(string /*_asset*/, uint256 _time) private constant returns (string) {
		// TODO: use asset in URL
		// TODO: use Binomo oracle
		return strConcat("json(https://min-api.cryptocompare.com/data/pricehistorical?fsym=ETH&tsyms=USD&ts=", uint2str(_time), ").ETH.USD");
	}

	function __callback(bytes32 selfId, string selfResult) {

		require(selfId != bytes32(0));
		require(msg.sender == oraclize_cbAddress());

		Deal memory deal = deals[selfId];
		require(deal.trend != Trend.Unknown);

		if (deal.firstQueryId == selfId && deal.secondQueryId == 0) {

			onGetResult("Got first result", selfResult);

			uint firstQueryResult = stringToUint(selfResult);
			deals[selfId].firstQueryResult = firstQueryResult;

			string memory url = buildOracleURL(deal.asset, deal.finishedAt);
			bytes32 secondQueryId = oraclize_query(deal.duration, "URL", url, gasLimitSecondQuery);

			// create deal for 2nd request coping 1st one
			deals[secondQueryId] = Deal({
				id: deal.id,
				traderWallet: deal.traderWallet,
				amount: deal.amount,
				paymentRate: deal.paymentRate,
				trend: deal.trend,
				asset: deal.asset,
				firstQueryId: 0,
				secondQueryId: secondQueryId,
				firstQueryResult: firstQueryResult,
				secondQueryResult: 0,
				createdAt: deal.createdAt,
				finishedAt: deal.finishedAt,
				duration: deal.duration
			});

			dealIdentifiers[deal.id] = secondQueryId;

		}
		else if (deal.firstQueryId == 0 && deal.secondQueryId == selfId) {

			onGetResult("Got second result", selfResult);

			uint secondQueryResult = stringToUint(selfResult);
			deal.secondQueryResult = secondQueryResult;
			deals[selfId].secondQueryResult = secondQueryResult;

			if (deal.firstQueryResult > deal.secondQueryResult) {
				if (Trend.Call == deal.trend) {
					investmentFails(deal);
				} else if (Trend.Put == deal.trend) {
					investmentSucceed(deal);
				}
			} else if (deal.firstQueryResult < deal.secondQueryResult) {
				if (Trend.Call == deal.trend) {
					investmentSucceed(deal);
				} else if (Trend.Put == deal.trend) {
					investmentFails(deal);
				}
			} else if (deal.firstQueryResult == deal.secondQueryResult) {
				investmentReturns(deal);
			}
		}
	}

	function investmentSucceed(Deal deal) private {

		totalDeals++;
		totalWins++;
		winRate = totalWins * 100 / totalDeals;

		uint amountWon = computeDealPaymentRate(deal.amount, deal.paymentRate);
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

	function computeDealPaymentRate(uint amount, uint paymentRate) private constant returns (uint) {
		return (amount * (100 + paymentRate)) / 100;
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

	function setDefaultPaymentRate(uint _value) ownerOnly {
		defaultPaymentRate = _value;
	}

	function setDefaultDuration(uint _value) ownerOnly {
		defaultDuration = _value;
	}

	function trendUintToEnum(uint value) private constant returns (Trend) {
		if (value == 1) {
			return Trend.Call;
		} else if (value == 2) {
			return Trend.Put;
		}
		return Trend.Unknown;
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
