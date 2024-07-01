const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("Lollipop_Mainnet", (m) => {
  const lollipop = m.contract("Lollipop", [
    "0xb77B8e2A7F3de960f37e1b93b9Bcc6f198EE401C", // Deployer
    "0x10ED43C718714eb63d5aA57B78B54704E256024E", // PancakeSwap Router V2
    "0xc26C83970a8f6F49a075Eea19CD4FaAd34ea3dF3", // fees receiver
  ]);

  m.call(lollipop, "initialize", []);

  return { lollipop };
});
