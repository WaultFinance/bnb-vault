const RewardPool = artifacts.require("RewardPool");

module.exports = function (deployer) {
  deployer.deploy(RewardPool);
};


// const RewardPool = artifacts.require("strategy/RewardPool");
// module.exports = function (deployer) {
//   deployer.deploy(RewardPool);
// };

// const StrategyVenusBNB = artifacts.require("strategy/StrategyVenusBNB");
// module.exports = function (deployer) {
//   const _vault = "";
//   const _borrowRate = 58;
//   const _borrowDepth = 4;
//   const _markets = "";
//   deployer.deploy(WaultVenusVaultBNB, _vault, _borrowRate, _borrowDepth, _markets);
// };


// const WaultVenusVaultBNB = artifacts.require("vaults/WaultVenusVaultBNB");
// module.exports = function (deployer) {
//   const _strategy = "";
//   const _name = "Wault Venus BNBB";
//   const _symbol = "WaultVenusBNB";
//   const _approvalDelay = 172800;
//   deployer.deploy(WaultVenusVaultBNB, _strategy, _name, _symbol, _approvalDelay);
// };
