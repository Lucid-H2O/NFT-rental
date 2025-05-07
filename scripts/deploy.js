import hre from 'hardhat';

async function main() {
    const [deployer] = await hre.ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    const NFTContractFactory = await hre.ethers.getContractFactory("RentableNFT");
    const NFTContract = await NFTContractFactory.deploy();
    await NFTContract.waitForDeployment();
    const contractAddress1 = await NFTContract.getAddress();
    console.log("RentableNFT deployed to:", contractAddress1);


}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });


