var Binomo = artifacts.require("./Binomo.sol");

contract('Binomo', function(accounts) {

  it("testing stringToUint function", async function() {
    let instance = await Binomo.deployed();
    
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
  });
   // ... more code
})