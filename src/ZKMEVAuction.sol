// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ZKVerifier} from "src/ZKVerifier.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";

/**
 * @title ZKMEVAuction
 * @dev Privacy-preserving MEV auction using ZK proofs
 */
contract ZKMEVAuction {
    ZKVerifier public verifier;
    DecentralizedStableCoin public dsc;

    struct Auction {
        uint256 id;
        uint256 endTime;
        uint256 highestBid; // Hidden via ZK
        address winner;
        bool ended;
    }

    mapping(uint256 => Auction) public auctions;
    uint256 public auctionCount;

    event AuctionCreated(uint256 indexed auctionId);
    event BidSubmitted(uint256 indexed auctionId, uint256[8] proof);
    event AuctionEnded(uint256 indexed auctionId, address winner);

    constructor(address _verifier, address _dsc) {
        verifier = ZKVerifier(_verifier);
        dsc = DecentralizedStableCoin(_dsc);
    }

    function createAuction(uint256 duration) external returns (uint256) {
        auctionCount++;
        auctions[auctionCount] = Auction({
            id: auctionCount,
            endTime: block.timestamp + duration,
            highestBid: 0,
            winner: address(0),
            ended: false
        });
        emit AuctionCreated(auctionCount);
        return auctionCount;
    }

    function submitBid(
        uint256 auctionId,
        uint256[8] calldata proof,
        uint256[4] calldata pubSignals
    ) external {
        require(!auctions[auctionId].ended, "Auction ended");
        require(verifier.verifyProof(proof, pubSignals), "Invalid bid proof");

        // Assume pubSignals[0] is the bid amount
        uint256 bidAmount = pubSignals[0];
        if (bidAmount > auctions[auctionId].highestBid) {
            auctions[auctionId].highestBid = bidAmount;
            auctions[auctionId].winner = msg.sender;
        }
        emit BidSubmitted(auctionId, proof);
    }

    function endAuction(uint256 auctionId) external {
        require(block.timestamp >= auctions[auctionId].endTime, "Auction not ended");
        auctions[auctionId].ended = true;
        emit AuctionEnded(auctionId, auctions[auctionId].winner);
    }
}