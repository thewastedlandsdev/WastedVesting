var WastedVesting = artifacts.require("WastedVesting");

module.exports = function(deployer) {
  // deployment steps
  deployer.deploy(WastedVesting, "0xA4441b7f6FD28814e29116C7bdeF0574e8288B8E");
};