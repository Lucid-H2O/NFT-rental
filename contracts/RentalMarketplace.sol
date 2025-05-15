// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./IERC4907.sol";

contract RentalMarketplace is ReentrancyGuard {
    struct RentalListing {
        address lender;
        uint256 rentalPricePerDay;
        uint256 minRentalDays;
        uint256 maxRentalDays;
        uint256 listExpiresAt;
    }

    mapping(address => mapping(uint256 => RentalListing)) public rentalListings;
    
    event ListedForRent(
        address indexed nftAddress,
        uint256 indexed tokenId,
        address indexed lender,
        uint256 rentalPricePerDay,
        uint256 minRentalDays,
        uint256 maxRentalDays,
        uint256 listExpiresAt
    );
    
    event RentCancelled(
        address indexed nftAddress,
        uint256 indexed tokenId,
        address indexed lender
    );
    
    event Rented(
        address indexed nftAddress,
        uint256 indexed tokenId,
        address indexed renter,
        uint256 rentalPricePerDay,
        uint256 rentalDays,
        uint256 rentalExpiresAt
    );

    modifier onlyLender(address nftAddress, uint256 tokenId) {
        require(
            rentalListings[nftAddress][tokenId].lender == msg.sender,
            "Not the lender"
        );
        _;
    }

    modifier isListed(address nftAddress, uint256 tokenId) {
        require(
            rentalListings[nftAddress][tokenId].lender != address(0),
            "NFT not listed"
        );
        _;
    }

    function listForRent(
        address nftAddress,
        uint256 tokenId,
        uint256 rentalPricePerDay,
        uint256 minRentalDays,
        uint256 maxRentalDays,
        uint256 listExpiresAt
    ) external {
        IERC4907 nft = IERC4907(nftAddress);
        require(nft.ownerOf(tokenId) == msg.sender, "Not the owner");
        require(nft.getApproved(tokenId) == address(this) || 
               nft.isApprovedForAll(msg.sender, address(this)), "Not approved");
        require(rentalPricePerDay > 0, "Rental price must be > 0");
        require(minRentalDays > 0, "Min rental days must be > 0");
        require(maxRentalDays >= minRentalDays, "Invalid rental range");
        require(listExpiresAt > block.timestamp, "Expiration must be future");
        require(nft.userOf(tokenId) == address(0), "NFT currently rented");

        rentalListings[nftAddress][tokenId] = RentalListing({
            lender: msg.sender,
            rentalPricePerDay: rentalPricePerDay,
            minRentalDays: minRentalDays,
            maxRentalDays: maxRentalDays,
            listExpiresAt: listExpiresAt
        });

        emit ListedForRent(
            nftAddress,
            tokenId,
            msg.sender,
            rentalPricePerDay,
            minRentalDays,
            maxRentalDays,
            listExpiresAt
        );
    }

    function cancelRentalListing(address nftAddress, uint256 tokenId)
        external
        isListed(nftAddress, tokenId)
        onlyLender(nftAddress, tokenId)
    {
        IERC4907 nft = IERC4907(nftAddress);
        require(nft.userOf(tokenId) == address(0), "NFT currently rented");
        
        delete rentalListings[nftAddress][tokenId];
        emit RentCancelled(nftAddress, tokenId, msg.sender);
    }

    function rent(
        address nftAddress,
        uint256 tokenId,
        uint256 rentalDays
    ) external payable nonReentrant isListed(nftAddress, tokenId) {
        RentalListing memory listing = rentalListings[nftAddress][tokenId];
        
        require(block.timestamp < listing.listExpiresAt, "Listing expired");
        require(rentalDays >= listing.minRentalDays, "Rental period too short");
        require(rentalDays <= listing.maxRentalDays, "Rental period too long");
        
        uint256 totalRentalPrice = listing.rentalPricePerDay * rentalDays;
        require(msg.value == totalRentalPrice, "Incorrect payment amount");

        IERC4907 nft = IERC4907(nftAddress);
        require(nft.ownerOf(tokenId) == listing.lender, "Lender no longer owner");
        require(nft.userOf(tokenId) == address(0), "NFT currently rented");

        uint256 rentalExpiresAt = block.timestamp + (rentalDays * 1 days);
        
        // Set the user and expiry
        nft.setUser(tokenId, msg.sender, uint64(rentalExpiresAt));
        
        // Transfer payment to lender
        payable(listing.lender).transfer(msg.value);
        
        // Remove listing after successful rental
        delete rentalListings[nftAddress][tokenId];
        
        emit Rented(
            nftAddress,
            tokenId,
            msg.sender,
            listing.rentalPricePerDay,
            rentalDays,
            rentalExpiresAt
        );
    }

    function getRentalListing(address nftAddress, uint256 tokenId)
        external
        view
        returns (RentalListing memory)
    {
        return rentalListings[nftAddress][tokenId];
    }
}