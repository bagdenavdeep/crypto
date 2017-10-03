var Binomo = artifacts.require("./Binomo.sol");
var UsingOraclize = artifacts.require("./UsingOraclize.sol");

module.exports = function(deployer) {
	deployer.deploy(UsingOraclize);
	deployer.link(UsingOraclize, Binomo);
	deployer.deploy(Binomo);
};
