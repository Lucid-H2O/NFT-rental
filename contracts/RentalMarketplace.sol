// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./IERC4907.sol";

contract ERC4907Marketplace is ReentrancyGuard {
    struct Listing {
        address seller;
        uint256 price;
        uint256 rentalPricePerDay;
        uint256 minRentalDays;
        uint256 maxRentalDays;
        uint256 expiresAt;
        bool isForSale;
        bool isForRent;
    }

    mapping(address => mapping(uint256 => Listing)) public listings;
    
    event ListedForSale(
        address indexed nftAddress,
        uint256 indexed tokenId,
        address indexed seller,
        uint256 price
    );
    
    event ListedForRent(
        address indexed nftAddress,
        uint256 indexed tokenId,
        address indexed seller,
        uint256 rentalPricePerDay,
        uint256 minRentalDays,
        uint256 maxRentalDays,
        uint256 expiresAt
    );
    
    event SaleCancelled(
        address indexed nftAddress,
        uint256 indexed tokenId,
        address indexed seller
    );
    
    event RentCancelled(
        address indexed nftAddress,
        uint256 indexed tokenId,
        address indexed seller
    );
    
    event Purchased(
        address indexed nftAddress,
        uint256 indexed tokenId,
        address indexed buyer,
        uint256 price
    );
    
    event Rented(
        address indexed nftAddress,
        uint256 indexed tokenId,
        address indexed renter,
        uint256 rentalPricePerDay,
        uint256 rentalDays,
        uint256 expiresAt
    );

    modifier onlySeller(address nftAddress, uint256 tokenId) {
        require(
            listings[nftAddress][tokenId].seller == msg.sender,
            "Not the seller"
        );
        _;
    }

    modifier isListed(address nftAddress, uint256 tokenId) {
        require(
            listings[nftAddress][tokenId].seller != address(0),
            "NFT not listed"
        );
        _;
    }

    function listForSale(
        address nftAddress,
        uint256 tokenId,
        uint256 price
    ) external {
        IERC721 nft = IERC721(nftAddress);
        require(nft.ownerOf(tokenId) == msg.sender, "Not the owner");
        require(nft.getApproved(tokenId) == address(this) || nft.isApprovedForAll(msg.sender, address(this)), "Not approved");
        require(price > 0, "Price must be greater than 0");

        listings[nftAddress][tokenId] = Listing({
            seller: msg.sender,
            price: price,
            rentalPricePerDay: 0,
            minRentalDays: 0,
            maxRentalDays: 0,
            expiresAt: 0,
            isForSale: true,
            isForRent: false
        });

        emit ListedForSale(nftAddress, tokenId, msg.sender, price);
    }

    function listForRent(
        address nftAddress,
        uint256 tokenId,
        uint256 rentalPricePerDay,
        uint256 minRentalDays,
        uint256 maxRentalDays,
        uint256 expiresAt
    ) external {
        IERC721 nft = IERC721(nftAddress);
        require(nft.ownerOf(tokenId) == msg.sender, "Not the owner");
        require(nft.getApproved(tokenId) == address(this) || nft.isApprovedForAll(msg.sender, address(this)), "Not approved");
        require(rentalPricePerDay > 0, "Rental price must be greater than 0");
        require(minRentalDays > 0, "Minimum rental days must be greater than 0");
        require(maxRentalDays >= minRentalDays, "Max rental days must be >= min rental days");
        require(expiresAt > block.timestamp, "Expiration must be in the future");

        listings[nftAddress][tokenId] = Listing({
            seller: msg.sender,
            price: 0,
            rentalPricePerDay: rentalPricePerDay,
            minRentalDays: minRentalDays,
            maxRentalDays: maxRentalDays,
            expiresAt: expiresAt,
            isForSale: false,
            isForRent: true
        });

        emit ListedForRent(
            nftAddress,
            tokenId,
            msg.sender,
            rentalPricePerDay,
            minRentalDays,
            maxRentalDays,
            expiresAt
        );
    }

    function cancelSale(address nftAddress, uint256 tokenId)
        external
        isListed(nftAddress, tokenId)
        onlySeller(nftAddress, tokenId)
    {
        require(listings[nftAddress][tokenId].isForSale, "Not listed for sale");
        
        delete listings[nftAddress][tokenId];
        
        emit SaleCancelled(nftAddress, tokenId, msg.sender);
    }

    function cancelRent(address nftAddress, uint256 tokenId)
        external
        isListed(nftAddress, tokenId)
        onlySeller(nftAddress, tokenId)
    {
        require(listings[nftAddress][tokenId].isForRent, "Not listed for rent");
        
        delete listings[nftAddress][tokenId];
        
        emit RentCancelled(nftAddress, tokenId, msg.sender);
    }

    function purchase(address nftAddress, uint256 tokenId)
        external
        payable
        nonReentrant
        isListed(nftAddress, tokenId)
    {
        Listing memory listing = listings[nftAddress][tokenId];
        require(listing.isForSale, "Not for sale");
        require(msg.value == listing.price, "Incorrect payment amount");

        IERC721 nft = IERC721(nftAddress);
        require(nft.ownerOf(tokenId) == listing.seller, "Seller no longer owner");

        delete listings[nftAddress][tokenId];
        
        nft.safeTransferFrom(listing.seller, msg.sender, tokenId);
        
        payable(listing.seller).transfer(msg.value);
        
        emit Purchased(nftAddress, tokenId, msg.sender, listing.price);
    }

    function rent(
        address nftAddress,
        uint256 tokenId,
        uint256 rentalDays
    ) external payable nonReentrant isListed(nftAddress, tokenId) {
        Listing memory listing = listings[nftAddress][tokenId];
        require(listing.isForRent, "Not for rent");
        require(block.timestamp < listing.expiresAt, "Listing expired");
        require(rentalDays >= listing.minRentalDays, "Rental period too short");
        require(rentalDays <= listing.maxRentalDays, "Rental period too long");
        
        uint256 totalRentalPrice = listing.rentalPricePerDay * rentalDays;
        require(msg.value == totalRentalPrice, "Incorrect payment amount");

        IERC4907 nft = IERC4907(nftAddress);
        require(nft.ownerOf(tokenId) == listing.seller, "Seller no longer owner");
        require(nft.userOf(tokenId) == address(0), "NFT is currently rented");

        uint256 expiresAt = block.timestamp + (rentalDays * 1 days);
        
        // Set the user and expiry
        nft.setUser(tokenId, msg.sender, expiresAt);
        
        // Transfer payment to seller
        payable(listing.seller).transfer(msg.value);
        
        emit Rented(
            nftAddress,
            tokenId,
            msg.sender,
            listing.rentalPricePerDay,
            rentalDays,
            expiresAt
        );
    }

    function getListing(address nftAddress, uint256 tokenId)
        external
        view
        returns (Listing memory)
    {
        return listings[nftAddress][tokenId];
    }
}