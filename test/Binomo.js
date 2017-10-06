var Binomo = artifacts.require("./Binomo.sol");

contract('Binomo', function(accounts) {

	it("testing stringToUint function", async () => {
		let instance = await Binomo.deployed();
		return await testStringToUint(instance)
	});

	it("create autonomous test deal", async () => {
		let instance = await Binomo.deployed();
		return await testAutonomousDeal(instance)
	})

	it("create test deal", async () => {
		let instance = await Binomo.deployed();
		return await testDeal(instance)
	})

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

		for (var item in items) {
			let value = await instance.stringToUint.call(item.s);
			assert.equal(value10.valueOf(), item.i, "wrong")			
		}
	}

	async function testAutonomousDeal(instance) {

		let tx = { 
			from: accounts[1], 
			to: instance.address, 
			value: web3.toWei(0.02, "ether"), 
			gas: 4712388 
		};

		let transactionHash = await web3.eth.sendTransaction(tx);

		// checkTransactionReceipt(transactionHash);

		// if (!await checkGasUsed(transactionHash)) {
		// 	return;
		// }

		await checkEvents(instance, "testAutonomousDeal");

	}

	async function testDeal(instance) {

		let dealId = "123";
		let assetId = "ETHUSD";
		let dealType = 1;
		let profit = 10;
		let dealTime = Math.floor(Date.now() / 1000);
		let expirationTime = dealTime + 60;

		let tx = {
			from: accounts[1], 
			value : web3.toWei(0.02, "ether"), 
			gas: 4712388
		};

		let transactionHash = await instance.createDeal.sendTransaction(dealId, assetId, dealType, profit, dealTime, expirationTime, tx);

		// checkTransactionReceipt(transactionHash);

		// if (!await checkGasUsed(transactionHash)) {
		// 	return;
		// }

		await checkEvents(instance, "testDeal");

	}

	async function checkEvents(instance, action) {

		let sender = web3.eth.accounts[1];

		var eventOnSuccess = instance.onSuccess({sender: sender});

		eventOnSuccess.watch(function(error, result) {
			if (error) {
		        console.log(error);
		        return;
		    }
			console.log(action + " onSuccess");
			console.log(result);
			console.log("\n");
			eventOnSuccess.stopWatching();
		});

		var eventOnGetResult = instance.onGetResult({sender: sender});

		eventOnGetResult.watch(function(error, result) {
			if (error) {
		        console.log(error);
		        return;
		    }
			console.log(action + " onGetResult " + result.logIndex);
			console.log(result);
			console.log("\n");
			if (result.logIndex > 1) {
				eventOnGetResult.stopWatching();
			}
		});

		var eventOnFinishDeal = instance.onFinishDeal({sender: sender});

		eventOnFinishDeal.watch(function(error, result) {
			if (error) {
		        console.log(error);
		        return;
		    }
			console.log(action + " onFinishDeal");
			console.log(result);
			console.log("\n");
			eventOnFinishDeal.stopWatching();
		});

		var eventOnChangeStatistics = instance.onChangeStatistics({sender: sender});

		eventOnChangeStatistics.watch(function(error, result) {
			if (error) {
		        console.log(error);
		        return;
		    }
			console.log(action + " onChangeStatistics");
			console.log(result);
			console.log("\n");
			eventOnChangeStatistics.stopWatching();
		});

	}

	// async function checkGasUsed(transactionHash) {
	//
	// 	let transaction = await web3.eth.getTransaction(transactionHash);
	// 	let transactionReceipt = await web3.eth.getTransactionReceipt(transactionHash);
	//
	// 	if (transactionReceipt == null) {
	// 		return false;
	// 	}
	//
	// 	if (transactionReceipt.gasUsed < transaction.gas) {
	// 		console.log('    Out of gas');
	// 		return false;
	// 	}
	//
	// 	return true;
	//
	// }

	// async function checkTransactionReceipt(transactionHash) {
	//
	// 	var countTransactionPending = web3.eth.getTransactionCount(web3.eth.accounts[1], "pending");
	//
	// 	if (parseInt(countTransactionPending) > 0) {
	// 		setTimeout(function() {
	// 			checkTransactionPending();
	// 		}, 60000);
	// 	}
	//
	// 	let transactionReceipt = web3.eth.getTransactionReceipt(transactionHash);
	//
	// 	if (transactionReceipt == null) {
	// 		setTimeout(function(transactionHash) {
	// 			checkTransactionReceipt(transactionHash);
	// 		}, 60000);
	// 	}
	// }

})
