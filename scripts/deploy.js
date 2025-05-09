import hre from 'hardhat';

async function main() {
    const [deployer] = await hre.ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    const NFTContractFactory = await hre.ethers.getContractFactory("RentableNFT");
    const NFTContract = await NFTContractFactory.deploy();
    await NFTContract.waitForDeployment();
    const contractAddress1 = await NFTContract.getAddress();
    console.log("RentableNFT deployed to:", contractAddress1);

    const ERC4907RentalMarketContractFactory = await hre.ethers.getContractFactory("ERC4907RentalMarket");
    const ERC4907RentalMarketContract = await ERC4907RentalMarketContractFactory.deploy();
    await ERC4907RentalMarketContract.waitForDeployment();
    const contractAddress2 = await ERC4907RentalMarketContract.getAddress();
    console.log("RentableNFT deployed to:", contractAddress2);


}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });


