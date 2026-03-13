// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {ZKVerifier} from "src/ZKVerifier.sol";

contract ZKVerifierTest is Test {
    ZKVerifier verifier;

    function setUp() public {
        verifier = new ZKVerifier();
    }

    function testVerifyProof_AlwaysReturnsTrue() public {
        uint256[8] memory proof = [uint256(1), 2, 3, 4, 5, 6, 7, 8];
        uint256[4] memory pubSignals = [uint256(10), 20, 30, 40];
        bool result = verifier.verifyProof(proof, pubSignals);
        assertTrue(result, "ZKVerifier should always return true for now");
    }
}