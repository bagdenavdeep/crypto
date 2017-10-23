var Binomo = artifacts.require("./Binomo.sol");

contract('Binomo', function(accounts) {

	const gasLimit = 4712388;
	const iterations = [1, 2, 3];
	const tx = {
		value : web3.toWei(0.02, "ether"),
		gas: gasLimit
	};

	// it("testing stringToUint function", async () => {
	// 	let instance = await Binomo.deployed();
	// 	return await testStringToUint(instance);
	// });
	//
	// it("create autonomous test deal", async () => {
	// 	let instance = await Binomo.deployed();
	// 	return await testAutonomousDeal(instance);
	// });

	it("create test deal", async () => {
		let instance = await Binomo.deployed();
		return await testDeal(instance);
	});

	async function testStringToUint(instance) {

		let mul = 100;

		let items = [
			{ s: "1",		i: 1*mul },
			{ s: "5",		i: 5*mul },
			{ s: "9",		i: 9*mul },
			{ s: "10",		i: 10*mul },
			{ s: "100",		i: 100*mul },
			{ s: "100.05",	i: 100*mul+5 },
			{ s: "100.5",	i: 100*mul+50 },
			{ s: "100.50",	i: 100*mul+50 },
			{ s: "1000",	i: 1000*mul },
			{ s: "1000.99", i: 1000*mul+99 },
		];

		for (let item in items) {
			let value = await instance.stringToUint.call(items[item].s);
			assert.equal(value.valueOf(), items[item].i, "wrong")
		}
	}

	async function testAutonomousDeal(instance) {

		await checkEvents(instance);

		for (let i in iterations) {
			await callAutonomousDeal(instance, iterations[i]);
			await delay(20);
		}

	}

	async function testDeal(instance) {

		await checkEvents(instance);

		for (let i in iterations) {
			await callCreateDeal(instance, iterations[i]);
			await delay(20);
		}

	}

	async function callCreateDeal(instance, i) {

		let dealId = (123 + parseInt(i)).toString();
		let assetId = "ETHUSD";
		let dealType = Math.floor(Math.random() * 2) + 1;
		let profit = 10;
		let dealTime = Math.floor(Date.now() / 1000) + i;
		let expirationTime = dealTime + 60 + i;

		tx['from'] = accounts[i];

		let transactionHash = await instance.createDeal.sendTransaction(
			dealId,
			assetId,
			dealType,
			profit,
			dealTime,
			expirationTime,
			tx
		);

		console.log(
			"params",
			" i:", i,
			" dealId:", dealId,
			" assetId:", assetId,
			" dealType:", dealType,
			" profit:", profit,
			" dealTime:", dealTime,
			" expirationTime:", expirationTime,
			" tx:", tx
		);

		console.log("testDeal: sendTransaction" + i + ": ", " from: " + tx['from'], "transactionHash: " + transactionHash);

	}

	async function callAutonomousDeal(instance, i) {

		tx['to'] = instance.address;
		tx['from'] = accounts[i];
		let transactionHash = await web3.eth.sendTransaction(tx);
		console.log("testAutonomousDeal: sendTransaction" + i + ": ", " from: " + tx['from'], "transactionHash: " + transactionHash);

	}

	async function checkEvents(instance) {

		let eventsCount = 0;
		let watchedEventsCount = 5 * iterations.length;
		console.log("watchedEventsCount: ", watchedEventsCount);

		let eventsHandler = instance.allEvents("onError", "onSuccess", "onGetResult", "onFinishDeal", "onChangeStatistics");
		eventsHandler.watch(function(error, event) {
			if (error) {
				console.log(error);
				return;
			}
			eventsCount++;
			console.log("eventsCount: ", eventsCount);
			console.log(event);
			logGas(event.transactionHash);
			console.log("\n");
			if (eventsCount == watchedEventsCount) {
				eventsHandler.stopWatching();
			}
		});

	}

	async function delay(ms) {
	    return new Promise(function (resolve) { return setTimeout(resolve, ms); });
	}

	function logGas(transactionHash) {
		let transactionReceipt = web3.eth.getTransactionReceipt(transactionHash);
		console.log("gasUsed: ", transactionReceipt.gasUsed);
	}

})
