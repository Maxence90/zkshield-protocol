// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {ZKCreditScore} from "src/ZKCreditScore.sol";
import {ZKVerifier} from "src/ZKVerifier.sol";
import {MerkleTreeManager} from "src/MerkleTreeManager.sol";

contract ZKCreditScoreTest is Test {
    ZKCreditScore creditScore;
    ZKVerifier verifier;
    MerkleTreeManager merkleTree;

    function setUp() public {
        verifier = new ZKVerifier();
        merkleTree = new MerkleTreeManager();
        creditScore = new ZKCreditScore(address(verifier), address(merkleTree));
    }

    function testSubmitCreditScoreProof_UpdatesScore() public {
        uint256[8] memory proof = [uint256(1), 2, 3, 4, 5, 6, 7, 8];
        uint256[4] memory pubSignals = [uint256(850), 0, 0, 0]; // Credit score 850

        creditScore.submitCreditScoreProof(proof, pubSignals);
        uint256 score = creditScore.getCreditScore(address(this));
        assertEq(score, 850, "Credit score should be updated");
    }
}