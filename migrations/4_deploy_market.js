const { deployProxy } = require('@openzeppelin/truffle-upgrades');
const WastedExpandMarket = artifacts.require("WastedExpandMarket");
// Deploy new contract
module.exports = async function (deployer) {
  const instance = await deployProxy(WastedExpandMarket, ['0x939722b4e2cCe97ae735de3376DA43c19A1dD77A', 0, 0], { initializer: 'initialize' });
  // deployer.deploy(WastedWhitelist, '0xd1a4A413C0f11904CE952C074F35d4D091D13497');
};