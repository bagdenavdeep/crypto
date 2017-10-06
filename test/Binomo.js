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

		let FMul = 100;

		let value10 = await instance.stringToUint.call("10");
		assert.equal(value10.valueOf(), 10*FMul, "10 wrong parsed")

		let value100 = await instance.stringToUint.call("100");
		assert.equal(value100.valueOf(), 100*FMul, "100 wrong parsed")

		let value100_5 = await instance.stringToUint.call("100.5");
		assert.equal(value100_5.valueOf(), 100*FMul+50, "100.5 wrong parsed")

		let value100_50 = await instance.stringToUint.call("100.50");
		assert.equal(value100_50.valueOf(), 100*FMul+50, "100.50 wrong parsed")

		let value100_05 = await instance.stringToUint.call("100.05");
		assert.equal(value100_05.valueOf(), 100*FMul+5, "100.05 wrong parsed")

		let value1000_99 = await instance.stringToUint.call("1000.99");
		assert.equal(value1000_99.valueOf(), 1000*FMul+99, "1000.99 wrong parsed")
	}

	async function testAutonomousDeal(instance) {

		let transactionHash = await web3.eth.sendTransaction({ from: accounts[1], to: instance.address, value: web3.toWei(0.02, "ether"), gas: 4712388 });

		// checkTransactionReceipt(transactionHash);

		// if (!await checkGasUsed(transactionHash)) {
		// 	return;
		// }

		await checkEvents(instance, "testAutonomousDeal");

	}

	async function testDeal(instance) {

		let dealTime = Math.floor(Date.now() / 1000);
		let expirationTime = dealTime + 60;

		let transactionHash = await instance.createDeal.sendTransaction("123", "ETHUSD", 1, 10, dealTime, expirationTime, {from: accounts[1], value : web3.toWei(0.02, "ether"), gas: 4712388})

		// checkTransactionReceipt(transactionHash);

		// if (!await checkGasUsed(transactionHash)) {
		// 	return;
		// }

		await checkEvents(instance, "testDeal");

	}

	async function checkEvents(instance, action) {

		var eventOnSuccess = instance.onSuccess({sender: web3.eth.accounts[1]});

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

		var eventOnGetResult = instance.onGetResult({sender: web3.eth.accounts[1]});

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

		var eventOnFinishDeal = instance.onFinishDeal({sender: web3.eth.accounts[1]});

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

		var eventOnChangeStatistics = instance.onChangeStatistics({sender: web3.eth.accounts[1]});

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
