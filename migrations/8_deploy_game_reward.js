var WastedGameReward = artifacts.require("WastedGameReward");

module.exports = function(deployer) {
    // deployment steps
    deployer.deploy(WastedGameReward, "0xA4441b7f6FD28814e29116C7bdeF0574e8288B8E");
};