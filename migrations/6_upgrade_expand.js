const { upgradeProxy } = require('@openzeppelin/truffle-upgrades');

const WastedExpand = artifacts.require('WastedExpand');

module.exports = async function (deployer) {
  const instance = await upgradeProxy('0x939722b4e2cCe97ae735de3376DA43c19A1dD77A', WastedExpand, { deployer });
  // console.log("Prev", existing.address);
  
  // console.log("Upgraded", instance.address);
};