import hre from 'hardhat';
import { assert, expect } from 'chai';

describe("NFTContract test", function () {
    let NFTContract;
    let account0, account1;

    beforeEach(async function () {
        [account0, account1] = await hre.ethers.getSigners();
        const NFTContractFactory = await hre.ethers.getContractFactory("RentableNFT", account0);
        NFTContract = await NFTContractFactory.deploy();
        await NFTContract.waitForDeployment();
    });

    it("should allow owner to mint an NFT", async function () {
        // Mint an NFT (account0 is owner)
        const tokenId = 1;
        const recipient = account1.address; // Mint to account1

        await NFTContract.connect(account0).mint(recipient, tokenId);

        // Check owner of tokenId
        const owner = await NFTContract.ownerOf(tokenId);
        expect(owner).to.equal(recipient);
    });
    

    it("should set user to Bob", async () => {
        // Get initial balances of first and second account.
        const Alice = account0;
        const Bob = account1;

        await NFTContract.connect(Alice).mint(Alice.address, 2);
        let expires = Math.floor(new Date().getTime()/1000) + 1000;
        await NFTContract.setUser(2, Bob, BigInt(expires));

        let user_1 = await NFTContract.userOf(2);

        assert.equal(
            user_1,
            Bob.address,
            "User of NFT 1 should be Bob"
        );

        let owner_1 = await NFTContract.ownerOf(2);
        assert.equal(
            owner_1,
            Alice.address ,
            "Owner of NFT 1 should be Alice"
        );
    });

});