pragma solidity ^0.4.0;

import "./Oraclize.sol";

contract Binomo is usingOraclize
{
	event onError(string status, address indexed sender);
	event onSuccess(string status, address indexed sender, uint amount);
	event onFinishDeal(string status, address indexed sender, uint predictedValue, uint realValue);
	event onChangeStatistics(uint totalDeals, uint totalWins, uint winRate, uint totalMoneyWon);

	uint public minAmount = 10000000000000000; // weis (0.01 ETH)
	uint public maxAmount = 50000000000000000; // weis (0.05 ETH)
	uint public defaultBonusPay = 10; // bonus for autonomous deals (percent of deal)
	uint public defaultDuration = 60; // duration of autonomous deals (in seconds)
	string public defaultAssetId = "ETHUSD";

	uint public totalDeals = 0;
	uint public totalMoneyWon = 0;
	uint public totalWins = 0;
	uint public winRate = 0;

	enum DealType {
		Unknown,	// unknown value
		Call, 		// trader predics that price will increase (use '1' in API)
		Put   		// trader predics that price will decrease (use '2' in API)
	}

	struct Deal {
		address traderWallet;		// address of trader's wallet
		uint amount;				// amount of tokens that trader has invested in deal
		uint bonusPay;				// percent of initial investment
		DealType dealType;			// type of deal: CALL / PUT
		string assetId;				// asset id to use in request to oracle
		bytes32 firstQueryId;		// id of 1st async query to oracle
		bytes32 secondQueryId;		// id of 2nd async query to oracle
		uint firstQueryResult;		// result of 1st query
		uint secondQueryResult;		// result of 2nd query
		uint256 dealTime;			// time when trader made an investment (UNIXTIME)
		uint256 expirationTime;		// expiration time (UNIXTIME)
		uint256 duration;			// delay to 2nd request to oracle
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

	address owner = 0;
	address brokerWallet = 0; // by default, broker is owner of contract (can be changed by owner)

	function Binomo() payable {
		owner = msg.sender;
		brokerWallet = msg.sender;
	}

	function createAutonomousDeal() payable {

		DealType dealType = dealTypeUintToEnum(getUintFromMsgData());
		require(dealType != DealType.Unknown);

		if (msg.value > maxAmount || msg.value < minAmount) {
			onError("Investment amount out of acceptable range", msg.sender);
			// msg.sender.transfer(msg.value - 2000);
		} else {
			onSuccess("Payment received", msg.sender, msg.value);

			uint256 dealTime = now; // current time of node (WARN: can be manipulated be node owner)
			uint256 expirationTime = dealTime + defaultDuration;
			string memory assetId = defaultAssetId;

			string memory url = buildOracleURL(assetId, dealTime);
			bytes32 queryId = oraclize_query("URL", url);

			deals[queryId] = Deal({
				traderWallet: msg.sender,
				amount: msg.value,
				bonusPay: defaultBonusPay,
				dealType: dealType,
				assetId: assetId,
				firstQueryId: queryId,
				secondQueryId: bytes32(0),
				firstQueryResult: 0,
				secondQueryResult: 0,
				dealTime: dealTime,
				expirationTime: expirationTime,
				duration: (expirationTime - dealTime)
			});
		}
	}

	function createDeal(address _traderWallet, string _assetId, uint _dealTypeInt, uint _bonusPay, uint256 _dealTime, uint256 _expirationTime) ownerOnly payable {

		if (msg.value > maxAmount || msg.value < minAmount) {
			onError("Investment amount out of acceptable range", _traderWallet);
			// msg.sender.transfer(amount - 2000);
		} else {

			onSuccess("Payment received", _traderWallet, msg.value);

			DealType dealType = dealTypeUintToEnum(_dealTypeInt);
			require(dealType != DealType.Unknown);

			require(_dealTime > 0);
			require(_expirationTime > _dealTime);

			string memory url = buildOracleURL(_assetId, _dealTime);
			bytes32 queryId = oraclize_query("URL", url);

			deals[queryId] = Deal({
				traderWallet: _traderWallet,
				amount: msg.value,
				bonusPay: _bonusPay,
				dealType: dealType,
				assetId: _assetId,
				firstQueryId: queryId,
				secondQueryId: bytes32(0),
				firstQueryResult: 0,
				secondQueryResult: 0,
				dealTime: _dealTime,
				expirationTime: _expirationTime,
				duration: (_expirationTime - _dealTime)
			});
		}
	}

	function buildOracleURL(string _assetId, uint256 _time) private constant returns(string) {
		// TODO: use assetId in URL
		_assetId = _assetId;
		// TODO: use Binomo oracle
		return strConcat("json(https://min-api.cryptocompare.com/data/pricehistorical?fsym=ETH&tsyms=USD&ts=", uint2str(_time), ").ETH.USD");
	}

	function __callback(bytes32 queryId, string result) {

		require(msg.sender == oraclize_cbAddress());
		require(queryId != bytes32(0));

		Deal memory deal = deals[queryId];

		require(deal.dealType != DealType.Unknown);

		if (deal.firstQueryId == queryId && deal.secondQueryId == 0) {

			string memory url = buildOracleURL(deal.assetId, deal.expirationTime);
			bytes32 secondQueryId = oraclize_query(deal.duration, "URL", url);

			// create deal for 2nd request coping 1st one
			deals[queryId] = Deal({
				traderWallet: deal.traderWallet,
				amount: deal.amount,
				bonusPay: deal.bonusPay,
				dealType: deal.dealType,
				assetId: deal.assetId,
				firstQueryId: bytes32(0),
				secondQueryId: secondQueryId,
				firstQueryResult: stringToUint(result),
				secondQueryResult: 0,
				dealTime: deal.dealTime,
				expirationTime: deal.expirationTime,
				duration: deal.duration
			});

		} else if (deal.firstQueryId == 0 && deal.secondQueryId == queryId) {

			deal.secondQueryResult = stringToUint(result);

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
				// TODO: узнать у Паши, какое мин. отклонение от исходного значения считается "равенством"
				investmentReturns(deal);
			}
		}
	}

	function investmentSucceed(Deal deal) private {

		totalDeals++;
		totalWins++;
		winRate = totalWins * 100 / totalDeals;

		uint amountWon = (deal.amount * (100 + deal.bonusPay)) / 100;
		totalMoneyWon += amountWon;

		deal.traderWallet.transfer(amountWon);

		onFinishDeal("Investment succeed", deal.traderWallet, deal.firstQueryResult, deal.secondQueryResult);
		onChangeStatistics(totalDeals, totalWins, winRate, totalMoneyWon);
	}

	function investmentFails(Deal deal) private {

		totalDeals++;
		winRate = totalWins * 100 / totalDeals;

		// TODO: обсудить с Никитой: куда уходят деньги проигравшей сделки
		// проблема: смарт-контракт не умеет делать переводы с чужого кошелька
		brokerWallet.transfer(deal.amount);
		/*deal.traderWallet.transfer(1); //-- not sure we should transfer money on fail*/

		onFinishDeal("Investment fails", deal.traderWallet, deal.firstQueryResult, deal.secondQueryResult);
		onChangeStatistics(totalDeals, totalWins, winRate, totalMoneyWon);
	}

	function investmentReturns(Deal deal) private {

		totalDeals++;
		winRate = totalWins * 100 / totalDeals;

		deal.traderWallet.transfer(deal.amount);

		onFinishDeal("Investment returns", deal.traderWallet, deal.firstQueryResult, deal.secondQueryResult);
		onChangeStatistics(totalDeals, totalWins, winRate, totalMoneyWon);
	}

	function drainBalance() payable ownerOnly {
		brokerWallet.transfer(this.balance);
	}

	function setMinAmount(uint _value) ownerOnly {
		minAmount = _value;
	}

	function setMaxAmount(uint _value) ownerOnly {
		maxAmount = _value;
	}

	function setDefaultBonusPay(uint _value) ownerOnly {
		defaultBonusPay = _value;
	}

	function setDefaultDuration(uint _value) ownerOnly {
		defaultDuration = _value;
	}

	function setBrokerWallet(address _value) ownerOnly {
		brokerWallet = _value;
	}

	function dealTypeUintToEnum(uint value) private constant returns(DealType) {
		if (value == 1) {
			return DealType.Call;
		} else if (value == 2) {
			return DealType.Put;
		}
		return DealType.Unknown;
	}

	function getUintFromMsgData() constant returns (uint) {
        uint x = 0;
        for (uint i = 0; i < 32; i++) {
            uint b = uint(msg.data[35 - i]);
            x += b * 256**i;
        }
        return x;
    }

	function stringToUint(string s) private constant returns (uint) {
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
