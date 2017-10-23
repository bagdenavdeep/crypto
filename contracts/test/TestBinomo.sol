pragma solidity ^0.4.2;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/Binomo.sol";

contract TestBinomo {

  function test10000() {
    Binomo instance = Binomo(DeployedAddresses.Binomo());

    uint FMul = 100;
    uint expected = 10*FMul+10;

    Assert.equal(instance.stringToUint("10.1"), expected, "Owner should have 10000 MetaCoin initially");
  }
/*
  function testInitialBalanceWithNewMetaCoin() {
    Binomo meta = new Binomo();

    uint expected = 10000;

    Assert.equal(meta.getBalance(tx.origin), expected, "Owner should have 10000 MetaCoin initially");
  }
*/
}
