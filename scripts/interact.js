const { ethers } = require("hardhat");

const contractAddress = "0xcCb181807bb845FE2ca80828069A5f529202Aea9";

async function main() {
  const contract = await ethers.getContractAt("Lollipop", contractAddress);
  // THIS ONE WORKS!
  // await contract.setRouter("0xD99D1c33F9fC3444f8101754aBC46c52416550D1");
  // console.log("Router set");
  await contract.distributeFee();
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
