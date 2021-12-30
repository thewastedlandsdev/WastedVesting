var WastedExpand = artifacts.require("WastedExpand");

module.exports = function(deployer) {
  // deployment steps
  deployer.deploy(WastedExpand,"https://test.thewastedlands.io/api/expand/");
};