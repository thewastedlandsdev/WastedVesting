var WastedStaking = artifacts.require("WastedStaking");

module.exports = function(deployer) {
  // deployment steps
  deployer.deploy(WastedStaking,"0xdeE71419bC45c11D28F9106cbb4923c7038Ed594", 0);
};