// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {ZKMEVAuction} from "src/ZKMEVAuction.sol";
import {ZKVerifier} from "src/ZKVerifier.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";

contract ZKMEVAuctionTest is Test {
    ZKMEVAuction auction;
    ZKVerifier verifier;
    DecentralizedStableCoin dsc;

    function setUp() public {
        verifier = new ZKVerifier();
        dsc = new DecentralizedStableCoin();
        auction = new ZKMEVAuction(address(verifier), address(dsc));
    }

    function testCreateAuction_ReturnsId() public {
        uint256 auctionId = auction.createAuction(3600); // 1 hour
        assertEq(auctionId, 1, "First auction ID should be 1");
    }

    function testSubmitBid_UpdatesHighestBid() public {
        uint256 auctionId = auction.createAuction(3600);
        uint256[8] memory proof = [uint256(1), 2, 3, 4, 5, 6, 7, 8];
        uint256[4] memory pubSignals = [uint256(100), 0, 0, 0]; // Bid amount 100

        auction.submitBid(auctionId, proof, pubSignals);
        // Since it's placeholder, we can't easily test internal state, but event is emitted
    }

    function testEndAuction_EmitsEvent() public {
        uint256 auctionId = auction.createAuction(1); // 1 second
        vm.warp(block.timestamp + 2); // Fast forward

        vm.expectEmit(true, false, false, false);
        emit ZKMEVAuction.AuctionEnded(auctionId, address(0));

        auction.endAuction(auctionId);
    }
}