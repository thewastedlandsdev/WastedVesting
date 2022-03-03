const { deployProxy } = require('@openzeppelin/truffle-upgrades');
const WastedCharacter = artifacts.require("WastedCharacter");
// Deploy new contract
module.exports = async function (deployer) {
  const instance = await deployProxy(WastedCharacter, ['https://api.thewastedlands.io/api/avatar/', 10000, 10, 0], {deployer: deployer, initializer: 'initialize' });
  // deployer.deploy(WastedWhitelist, '0xd1a4A413C0f11904CE952C074F35d4D091D13497');
};