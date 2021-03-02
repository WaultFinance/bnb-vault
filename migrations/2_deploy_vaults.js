const WaultBnbStrategy = artifacts.require("WaultBnbStrategy");
const WaultVaultBNB = artifacts.require("WaultVaultBNB");

module.exports = function (deployer) {

  deployer.deploy(WaultBnbStrategy);
  // deployer.deploy(WaultVaultBNB, "0xFA3CcB086Bf371A2Ff33Db8521Be47c5B4b9d10E", "Wault Vault BNB", "WaultVaultBNB", 172800);

};
