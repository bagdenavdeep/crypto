var Binomo = artifacts.require("./Binomo.sol");

module.exports = function(deployer) {
  deployer.deploy(Binomo);
  deployer.link(Binomo);
};
