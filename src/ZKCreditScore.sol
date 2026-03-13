// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ZKVerifier} from "src/ZKVerifier.sol";
import {MerkleTreeManager} from "src/MerkleTreeManager.sol";

/**
 * @title ZKCreditScore
 * @dev ZK proof for DeFi credit scores
 */
contract ZKCreditScore {
    ZKVerifier public verifier;
    MerkleTreeManager public merkleTree;

    mapping(address => uint256) public userScores; // For simplicity, store scores

    event ScoreProven(address indexed user, uint256 score);

    constructor(address _verifier, address _merkleTree) {
        verifier = ZKVerifier(_verifier);
        merkleTree = MerkleTreeManager(_merkleTree);
    }

    function submitCreditScoreProof(
        uint256[8] calldata proof,
        uint256[4] calldata pubSignals
    ) external {
        require(verifier.verifyProof(proof, pubSignals), "Invalid credit score proof");

        // Assume pubSignals[0] is the credit score
        uint256 score = pubSignals[0];
        userScores[msg.sender] = score;

        emit ScoreProven(msg.sender, score);
    }

    function getCreditScore(address user) external view returns (uint256) {
        return userScores[user];
    }
}