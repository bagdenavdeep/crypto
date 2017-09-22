pragma solidity ^0.4.0;

import "./Oraclize.sol";

contract Binomo is usingOraclize
{
    event success(string status, address indexed etherSentBy);
    event traderResult(string result, address indexed trader, uint firstResultFromOraclize, uint secondResultFromOraclize, uint time);
    event stats(uint indexed totalDills, uint indexed totalAmountWon, uint indexed totalDillsWon, uint winRate);

	uint public minDill 		   = 10000000000000000; // In wei (0.01 ETH)
    uint public maxDill   		   = 50000000000000000; // In wei (0.05 ETH)
	uint public percentWin 		   = 75;
	uint public secondsNextRequest = 60;

	address walletBinomo		   = 0x2cf8f59a7e5d01e6ec090cad7f010f0007ac2a45;

    uint public totalDills;
    uint public etherWin;
    uint public winBets;
    uint public winRate;

	enum action {call, put}

    struct Trader {
		address traderAddress;
		uint traderDillValue;
		bytes32 firstQueryIdFromOraclize;
		bytes32 secondQueryIdFromOraclize;
		uint firstResultFromOraclize;
		uint secondResultFromOraclize;
		bool traderIsBinomo;
		uint256 traderUnixtime;
		uint256 traderUnixtimeExpire;
		string traderQuote;
		action traderAction;
	}

    mapping (bytes32 => Trader) Traders;

    address owner;

    modifier onlyOwner() {
		require(msg.sender == owner);
        _;
    }

	function () payable {
		require(msg.sender != owner);
		createDill();
	}

    function createDill() payable {
       if (msg.value > maxDill || msg.value < minDill) {
           success("Invalid payment", msg.sender);
           /*msg.sender.transfer(msg.value - 2000);*/
       } else {
	       success("Payment received", msg.sender);

		   bytes32 id = oraclize_query("URL", "json(https://min-api.cryptocompare.com/data/price?fsym=ETH&tsyms=USD).USD");

	       Traders[id].traderAddress = msg.sender;
	       Traders[id].traderDillValue = msg.value;
	       Traders[id].firstQueryIdFromOraclize = id;
	       Traders[id].secondQueryIdFromOraclize = bytes32(0);
		   Traders[id].traderIsBinomo = false;
		   /*Traders[id].traderQuote = 'ETHUSD';*/
		   /*Traders[id].traderAction = action.action;*/
       }
    }

	function createDillBinomo(string quoteBinomo, uint256 unixtimeBinomo, uint256 unixtimeExpireBinomo) onlyOwner payable {

		if (msg.value > maxDill || msg.value < minDill) {
			success("Invalid payment", msg.sender);
			/*msg.sender.transfer(amount - 2000);*/
		} else {
			success("payment received", msg.sender);

			bytes32 id = oraclize_query("URL", strConcat("json(https://min-api.cryptocompare.com/data/pricehistorical?fsym=ETH&tsyms=USD&ts=", uint2str(unixtimeBinomo), ").ETH.USD"));

			Traders[id].traderAddress = msg.sender;
			Traders[id].traderDillValue = msg.value;
			Traders[id].firstQueryIdFromOraclize = id;
			Traders[id].secondQueryIdFromOraclize = bytes32(0);
			Traders[id].traderIsBinomo = true;
			/*Traders[id].traderAction = actionBinomo.action;*/

		}
	}

    function Binomo() payable {
        owner = msg.sender;
    }

	function __callback(bytes32 currentId, string result) {

		require(msg.sender == oraclize_cbAddress());

		if (Traders[currentId].firstQueryIdFromOraclize == currentId && Traders[currentId].secondQueryIdFromOraclize == 0) {

		    Traders[currentId].firstResultFromOraclize = stringToUint(result);

			bytes32 id;

			if (Traders[currentId].traderIsBinomo) {
				id = oraclize_query(Traders[currentId].unixtimeExpire - Traders[currentId].unixtime, "URL", strConcat("json(https://min-api.cryptocompare.com/data/pricehistorical?fsym=ETH&tsyms=USD&ts=", uint2str(Traders[currentId].unixtimeExpire), ").ETH.USD"));
			} else {
				id = oraclize_query(secondsNextRequest, "URL","json(https://min-api.cryptocompare.com/data/price?fsym=ETH&tsyms=USD).USD");
			}

		    Traders[currentId].firstQueryIdFromOraclize = bytes32(0);

		    Traders[id].firstQueryIdFromOraclize = bytes32(0);
		    Traders[id].traderAddress = Traders[currentId].traderAddress;
		    Traders[id].traderDillValue = Traders[currentId].traderDillValue;
		    Traders[id].firstResultFromOraclize = Traders[currentId].firstResultFromOraclize;
		    Traders[id].secondQueryIdFromOraclize = id;

		} else if (Traders[currentId].secondQueryIdFromOraclize == currentId && Traders[currentId].firstQueryIdFromOraclize == 0) {

		    Traders[currentId].secondResultFromOraclize = stringToUint(result);

			if (Traders[currentId].traderAction) {

			}

			/*if (isBinomo) {
				if ((Traders[myid].queryResult1 < Traders[myid].queryResult2) || (Traders[myid].queryResult1 > Traders[myid].queryResult2)) {
					betBinomoWin(myid);
				} else if ((Traders[myid].queryResult1 > Traders[myid].queryResult2) || (Traders[myid].queryResult1 < Traders[myid].queryResult2)) {
					betBinomoLose(myid);
				}
			} else {
				if ((owner == addressUp && Traders[myid].queryResult1 < Traders[myid].queryResult2) || (owner == addressDown && Traders[myid].queryResult1 > Traders[myid].queryResult2)) {
					betWin(myid);
				} else if ((owner == addressUp && Traders[myid].queryResult1 > Traders[myid].queryResult2) || (owner == addressDown && Traders[myid].queryResult1 < Traders[myid].queryResult2)) {
					betLose(myid);
				}
			}*/
		}
	}

	function dillWin(bytes32 currentId) {
		totalDills++;
		winBets++;
		winRate = winDills * 100 / totalDills;
		etherWin = etherWin + ((Traders[currentId].traderDillValue * percentWin) / 100);
		traderResult("WIN", Traders[currentId].traderAddress, Traders[currentId].firstResultFromOraclize, Traders[currentId].secondResultFromOraclize, now);
		winnerReward(Traders[currentId].traderAddress, Traders[currentId].traderDillValue);
	}

	function dillLose(bytes32 currentId) {
		totalDills++;
		winRate = winBets * 100 / totalDills;
		traderResult("LOSE", Traders[currentId].traderAddress, Traders[currentId].firstResultFromOraclize, Traders[currentId].secondResultFromOraclize, now);
		loser(Traders[currentId].traderAddress);
	}

    function winnerReward(address trader, uint dillValue) payable {
        uint winningAmount = (dillValue * (100 + percentWin)) / 100;
        trader.transfer(winningAmount);
        stats(totalDills, etherWin, winBets, winRate);
    }

    function loser(address trader) payable {
        trader.transfer(1);
        stats(totalDills, etherWin, winBets, winRate);
    }

	function drain() payable onlyOwner {
		owner.transfer(this.balance);
	}

	function setMinBet(uint newMinBet) onlyOwner {
	    minDill = newMinBet;
	}

	function setMaxBet(uint newMaxBet) onlyOwner {
	    maxDill = newMaxBet;
	}

	function setPercentWin(uint newPercentWin) onlyOwner {
	    percentWin = newPercentWin;
	}

	function setSecondsNextRequest(uint newSecondsNextRequest) onlyOwner {
	    secondsNextRequest = newSecondsNextRequest;
	}

	function stringToUint(string s) returns (uint) {
		bytes memory b = bytes(s);
		uint i;
		uint result1 = 0;
		for (i = 0; i < b.length; i++) {
		    uint c = uint(b[i]);
		    if (c == 46) {
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
