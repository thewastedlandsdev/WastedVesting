var WastedVesting = artifacts.require("WastedVesting");

module.exports = function(deployer) {
  // deployment steps
  deployer.deploy(WastedVesting,"0x0329958a15ad1d9ba7836425c998c69a92067cc0");
};