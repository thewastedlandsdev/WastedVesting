var WastedGameReward = artifacts.require("WastedGameReward");

module.exports = function(deployer) {
  // deployment steps
  deployer.deploy(WastedGameReward, "0xd306c124282880858a634E7396383aE58d37c79c");
};