const { ethers } = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    // Deploy RentableNFT
    const NFTContractFactory = await ethers.getContractFactory("RentableNFT");
    const NFTContract = await NFTContractFactory.deploy();
    await NFTContract.waitForDeployment();
    console.log("RentableNFT deployed to:", await NFTContract.getAddress());

    // Deploy RentalMarketplace
    const RentalMarketContractFactory = await ethers.getContractFactory("RentalMarketplace");
    const RentalMarketContract = await RentalMarketContractFactory.deploy();
    await RentalMarketContract.waitForDeployment();
    console.log("RentalMarketplace deployed to:", await RentalMarketContract.getAddress());
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });


