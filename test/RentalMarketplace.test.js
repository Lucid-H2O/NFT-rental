const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("RentalMarketplace", function () {
  const DAY_SECONDS = 86400; //1 day
  let RentalMarketplace, RentalNFC, owner, renter, other;
  let marketplace, nft;

  beforeEach(async function () {
    [owner, renter, other] = await ethers.getSigners();

    const RentalNFTFactory = await ethers.getContractFactory("RentableNFT");
    nft = await RentalNFTFactory.deploy();
    
    const MarketplaceFactory = await ethers.getContractFactory("RentalMarketplace");
    marketplace = await MarketplaceFactory.deploy();

    await nft.mint(owner.address, 1);
    await nft.connect(owner).setApprovalForAll(await marketplace.getAddress(), true);
  });

  it("should list NFT for rent", async function () {
    const pricePerDay = ethers.parseEther("1");
    const minDays = 1;
    const maxDays = 7;
    const listExpiresAt = (await ethers.provider.getBlock("latest")).timestamp + DAY_SECONDS;

    await expect(
      marketplace.connect(owner).listForRent(
        await nft.getAddress(),
        1,
        pricePerDay,
        minDays,
        maxDays,
        listExpiresAt
      )
    ).to.emit(marketplace, "ListedForRent");

    const listing = await marketplace.getRentalListing(await nft.getAddress(), 1);
    expect(listing.lender).to.equal(owner.address);
    expect(listing.rentalPricePerDay).to.equal(pricePerDay);
    expect(listing.minRentalDays).to.equal(minDays)
    expect(listing.maxRentalDays).to.equal(maxDays)
    expect(listing.listExpiresAt).to.equal(listExpiresAt)
  });


  it("should handle rental lifecycle correctly", async function () {
    const pricePerDay = ethers.parseEther("0.5");
    const rentalDays = 3n;
    const totalPrice = pricePerDay * rentalDays;

    //list NFT
    await marketplace.connect(owner).listForRent(
      await nft.getAddress(), 
      1,
      pricePerDay,
      1,
      7,
      (await ethers.provider.getBlock("latest")).timestamp + DAY_SECONDS
    );

    //rent NFT
    const renterBalanceBefore = await ethers.provider.getBalance(renter.address);
    const tx = await marketplace.connect(renter).rent(
      await nft.getAddress(),
      1,
      rentalDays,
      { value: totalPrice }
    );
    const receipt = await tx.wait();
    const gasUsed = receipt.gasUsed * receipt.gasPrice;

    //verify rental
    expect(await nft.userOf(1)).to.equal(renter.address);
    
    //verify funds
    const renterBalanceAfter = await ethers.provider.getBalance(renter.address);
    expect(renterBalanceBefore - renterBalanceAfter).to.equal(gasUsed + totalPrice);

    //verify expiration
    await ethers.provider.send("evm_increaseTime", [Number(BigInt(DAY_SECONDS) * rentalDays) + 1]);
    await ethers.provider.send("evm_mine");
    expect(await nft.userOf(1)).to.equal(ethers.ZeroAddress);
  });

  it("should prevent invalid rentals", async function () {
    await marketplace.connect(owner).listForRent(
      await nft.getAddress(),
      1,
      ethers.parseEther("1"),
      2, //minDays
      5, //maxDays
      (await ethers.provider.getBlock("latest")).timestamp + DAY_SECONDS
    );

    //test under-min duration
    await expect(
      marketplace.connect(renter).rent(
        await nft.getAddress(),
        1,
        1, // 1 day (below minimum)
        { value: ethers.parseEther("1") }
      )
    ).to.be.revertedWith("Rental period too short");

    //test over-max duration
    await expect(
      marketplace.connect(renter).rent(
        await nft.getAddress(),
        1,
        6, // 6 days (over maximum)
        { value: ethers.parseEther("6") }
      )
    ).to.be.revertedWith("Rental period too long");
  });

  afterEach(async function () {
    await ethers.provider.send("hardhat_reset");
  });
});