// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ZKVerifier} from "./ZKVerifier.sol";
import {DSCEngine} from "src/DSCEngine.sol";

/**
 * @title ZKLiquidationProof
 * @dev Handles ZK proofs for liquidation prevention
 */
contract ZKLiquidationProof {
    ZKVerifier public verifier;
    DSCEngine public dscEngine;

    event LiquidationPrevented(address indexed user, uint256 healthFactor);

    constructor(address _verifier, address _dscEngine) {
        verifier = ZKVerifier(_verifier);
        dscEngine = DSCEngine(_dscEngine);
    }

    function submitLiquidationProof(
        uint256[8] calldata proof,
        uint256[4] calldata pubSignals
    ) external {
        require(verifier.verifyProof(proof, pubSignals), "Invalid proof");

        // Assume pubSignals[0] is the proven health factor
        uint256 provenHealthFactor = pubSignals[0];
        require(provenHealthFactor >= dscEngine.MIN_HEALTH_FACTOR(), "Health factor too low");

        emit LiquidationPrevented(msg.sender, provenHealthFactor);
    }
}