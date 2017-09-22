pragma solidity ^0.4.0;

import "./Oraclize.sol";

contract Binomo is usingOraclize
{
    event UpSuccess(string status, address indexed EtherSentBy);
    event UpPlayerResult(string result, address indexed player, uint query1Result, uint query2Result, uint time);
    event UpStats(uint indexed totalBets, uint indexed total_amount_won, uint indexed total_bets_won, uint win_rate);

    uint public UP_totalBets; // to store total no of bets
    uint public UP_etherWin; // total amount of ether Won by players
    uint public UP_winBets; // total no of bets
    uint public UP_winRate; // to store win rate percentage
    uint public min_bet = 10000000000000000; // In wei (0.01 ETH)
    uint public max_bet = 50000000000000000; // In wei (0.05 ETH)
	uint public percentWin = 75;
	uint256 public unixtime;
	uint256 public unixtimeExpire;
	address public addressUp = 0xea42f5352350f65823ab97670c7bd7410c322f0b;
	address public addressDown = 0x51a0263dba30b40c7057c614476d02f5f1e4dbe0;
	bool public isBinomo = false;
	string public quote;

    struct Player {
		address playerAddress;
		uint playerbetvalue;
		bytes32 queryid1;
		bytes32 queryid2;
		uint queryResult1;
		uint queryResult2;
	}

    mapping (bytes32 => Player) Players;

    address owner;   //address owner of the contract

    // Functions with this modifier can only be executed by the owner
    modifier onlyOwner() {
		require(msg.sender == owner);
        _;
    }

	function ()payable {
		if (msg.sender == owner) {
			UpSuccess("Contract is funded", owner);
		} else {
			createBet();
		}
	}

    function createBet()payable {
       if (msg.value > max_bet || msg.value < min_bet) {
           UpSuccess("Invalid payment", msg.sender);
           /*msg.sender.transfer(msg.value - 2000);*/
       } else {
	       UpSuccess("payment received", msg.sender);

		   bytes32 rngId1 = oraclize_query("URL", "json(https://min-api.cryptocompare.com/data/price?fsym=ETH&tsyms=USD).USD");

	       Players[rngId1].playerAddress = msg.sender;
	       Players[rngId1].playerbetvalue = msg.value;
	       Players[rngId1].queryid1 = rngId1;
	       Players[rngId1].queryid2 = bytes32(0);
       }
    }

	function createBetBinomo()payable {
		if (msg.value > max_bet || msg.value < min_bet) {
			UpSuccess("Invalid payment", msg.sender);
			/*msg.sender.transfer(amount - 2000);*/
		} else {
			UpSuccess("payment received", msg.sender);

			isBinomo = true;

			bytes32 rngId1 = oraclize_query("URL", strConcat("json(https://min-api.cryptocompare.com/data/pricehistorical?fsym=ETH&tsyms=USD&ts=", uint2str(unixtime), ").ETH.USD"));

			Players[rngId1].playerAddress = msg.sender;
			Players[rngId1].playerbetvalue = msg.value;
			Players[rngId1].queryid1 = rngId1;
			Players[rngId1].queryid2 = bytes32(0);

		}
	}

    function Binomo()payable {
        owner = msg.sender;
    }

	function __callback(bytes32 myid, string result) {

		// just to be sure the calling address is the Oraclize authorized one
		if (!isBinomo) {
			require(msg.sender == oraclize_cbAddress());
		}

		if (Players[myid].queryid1 == myid && Players[myid].queryid2 == 0) {

		    Players[myid].queryResult1 = stringToUint(result);

			bytes32 rngId2;

			if (isBinomo) {
				rngId2 = oraclize_query(unixtimeExpire - unixtime, "URL", strConcat("json(https://min-api.cryptocompare.com/data/pricehistorical?fsym=ETH&tsyms=USD&ts=", uint2str(unixtimeExpire), ").ETH.USD"));
			} else {
				rngId2 = oraclize_query(60, "URL","json(https://min-api.cryptocompare.com/data/price?fsym=ETH&tsyms=USD).USD");
			}

		    Players[myid].queryid1 = bytes32(0);

		    Players[rngId2].queryid1 = bytes32(0);
		    Players[rngId2].playerAddress = Players[myid].playerAddress;
		    Players[rngId2].playerbetvalue = Players[myid].playerbetvalue;
		    Players[rngId2].queryResult1 = Players[myid].queryResult1;
		    Players[rngId2].queryid2 = rngId2;

		} else if (Players[myid].queryid2 == myid && Players[myid].queryid1 == 0) {

		    /* the result is checked based on the results fetched in call back function */

		    Players[myid].queryResult2 = stringToUint(result);

			if (isBinomo) {
				if ((Players[myid].queryResult1 < Players[myid].queryResult2) || (Players[myid].queryResult1 > Players[myid].queryResult2)) {
					betBinomoWin(myid);
				} else if ((Players[myid].queryResult1 > Players[myid].queryResult2) || (Players[myid].queryResult1 < Players[myid].queryResult2)) {
					betBinomoLose(myid);
				}
			} else {
				if ((owner == addressUp && Players[myid].queryResult1 < Players[myid].queryResult2) || (owner == addressDown && Players[myid].queryResult1 > Players[myid].queryResult2)) {
					betWin(myid);
				} else if ((owner == addressUp && Players[myid].queryResult1 > Players[myid].queryResult2) || (owner == addressDown && Players[myid].queryResult1 < Players[myid].queryResult2)) {
					betLose(myid);
				}
			}
		}
	}

	function betWin(bytes32 myid) {
		// Player wins
		UP_totalBets++;
		UP_winBets++;
		UP_winRate = UP_winBets * 100 / UP_totalBets; // Must be DIVIDED BY 100 when displayed on frontend
		UP_etherWin = UP_etherWin + ((Players[myid].playerbetvalue * percentWin) / 100);
		UpPlayerResult("WIN", Players[myid].playerAddress, Players[myid].queryResult1, Players[myid].queryResult2, now);
		winnerReward(Players[myid].playerAddress, Players[myid].playerbetvalue);
	}

	function betLose(bytes32 myid) {
		// Player loses
		UP_totalBets++;
		UP_winRate = UP_winBets * 100 / UP_totalBets;
		UpPlayerResult("LOSE", Players[myid].playerAddress, Players[myid].queryResult1, Players[myid].queryResult2, now);
		loser(Players[myid].playerAddress);
	}

	function betBinomoWin(bytes32 myid) {
		UP_etherWin = UP_etherWin + ((Players[myid].playerbetvalue * percentWin) / 100);
		UpPlayerResult("WIN", Players[myid].playerAddress, Players[myid].queryResult1, Players[myid].queryResult2, now);
		winnerReward(Players[myid].playerAddress, Players[myid].playerbetvalue);
	}

	function betBinomoLose(bytes32 myid) {
		UpPlayerResult("LOSE", Players[myid].playerAddress, Players[myid].queryResult1, Players[myid].queryResult2, now);
		loser(Players[myid].playerAddress);
	}

	function actionBinomo(string quoteBinomo, uint256 unixtimeBinomo, uint256 unixtimeExpireBinomo) payable {
		if (msg.sender == owner) {
			UpSuccess("Contract is funded", owner);
		} else {
			quote   	   = quoteBinomo;
			unixtime 	   = unixtimeBinomo;
			unixtimeExpire = unixtimeExpireBinomo;
			createBetBinomo();
		}
	}

    function winnerReward(address player, uint betvalue) payable {
        uint winningAmount = (betvalue * (100 + percentWin)) / 100;
        player.transfer(winningAmount);
        UpStats(UP_totalBets, UP_etherWin, UP_winBets, UP_winRate);
    }

    function loser(address player) payable {
        player.transfer(1);
        UpStats(UP_totalBets, UP_etherWin, UP_winBets, UP_winRate);
    }

  	/* Failsafe drain - owner can withdraw all the ether from the contract */
	function drain()payable onlyOwner {
		owner.transfer(this.balance);
	}

	function setMinBet(uint newMinBet) onlyOwner {
	    min_bet = newMinBet;
	}

	function setMaxBet(uint newMaxBet) onlyOwner {
	    max_bet = newMaxBet;
	}

	function setAddressUp(address newAddressUp) onlyOwner {
	    addressUp = newAddressUp;
	}

	function setAddressDown(address newAddressDown) onlyOwner {
	    addressDown = newAddressDown;
	}

	function setPercentWin(uint newPercentWin) onlyOwner {
	    percentWin = newPercentWin;
	}

	// Below function will convert string to integer removing decimal
	function stringToUint(string s) returns (uint) {
		bytes memory b = bytes(s);
		uint i;
		uint result1 = 0;
		for (i = 0; i < b.length; i++) {
		    uint c = uint(b[i]);
		    if (c == 46) {
		        // Do nothing --this will skip the decimal
		    } else if (c >= 48 && c <= 57) {
		        result1 = result1 * 10 + (c - 48);
		      // usd_price = result;
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
