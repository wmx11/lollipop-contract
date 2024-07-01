const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("Lollipop10", (m) => {
  const lollipop = m.contract("Lollipop", [
    "0xb3A7Ab89c3a0e209b45338f1eCe30Dc246C0c4c0",
    "0xD99D1c33F9fC3444f8101754aBC46c52416550D1",
    "0x87eF9b0815a1bcD872d9dB55D73940bA612e718f",
  ]);

  m.call(lollipop, "initialize", []);

  return { lollipop };
});
