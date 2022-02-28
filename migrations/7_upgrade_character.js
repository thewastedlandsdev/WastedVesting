const { upgradeProxy } = require('@openzeppelin/truffle-upgrades');

const WastedCharacter = artifacts.require('WastedCharacter');

module.exports = async function (deployer) {
  const instance = await upgradeProxy('0x5d2207DC649419707EF5a5e01A729204dC69A9A9', WastedCharacter, { deployer });
  // console.log("Prev", existing.address);
  
  // console.log("Upgraded", instance.address);
};