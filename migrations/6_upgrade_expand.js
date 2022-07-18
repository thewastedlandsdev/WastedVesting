const { upgradeProxy } = require('@openzeppelin/truffle-upgrades');

const WastedExpand = artifacts.require('WastedExpand');

module.exports = async function (deployer) {
  const instance = await upgradeProxy('0x9E8Cc1c864De068D46Ed5c8c9612Eb02d5b35BB9', WastedExpand, { deployer });
  // console.log("Prev", existing.address);
  
  // console.log("Upgraded", instance.address);
};