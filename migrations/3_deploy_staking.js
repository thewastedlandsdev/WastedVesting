var WastedStaking = artifacts.require("WastedStaking");

module.exports = function(deployer) {
  // deployment steps
  deployer.deploy(WastedStaking,"0x157B9dC01CE3993f45580C1036065Ec18Ad649e5", 0);
};