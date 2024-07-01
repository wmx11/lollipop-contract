const { ethers } = require("hardhat");

const contractAddress = "0xAF4B52275C0d1a0f5b7BF9e3187120Ea30a79dD2";

async function main() {
  const contract = await ethers.getContractAt("Lollipop", contractAddress);
  await contract.distributeFee();
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
