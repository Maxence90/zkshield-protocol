// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {DSCEngine} from "src/DSCEngine.sol";
import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ZKVerifier} from "./ZKVerifier.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title PrivateLendingCore
 * @dev Core for private lending with ZK proofs
 */
contract PrivateLendingCore {
    DSCEngine public dscEngine;
    DecentralizedStableCoin public dsc;
    ZKVerifier public verifier;

    event PrivateDeposit(address indexed user, uint256 amount);
    event PrivateBorrow(address indexed user, uint256 amount);

    constructor(address _dscEngine, address _dsc, address _verifier) {
        dscEngine = DSCEngine(_dscEngine);
        dsc = DecentralizedStableCoin(_dsc);
        verifier = ZKVerifier(_verifier);
    }

    function privateDeposit(
        address token,
        uint256 amount,
        uint256[8] calldata proof,
        uint256[4] calldata pubSignals
    ) external {
        require(verifier.verifyProof(proof, pubSignals), "Invalid deposit proof");

        // Transfer token from user to engine
        IERC20(token).transferFrom(msg.sender, address(dscEngine), amount);

        emit PrivateDeposit(msg.sender, amount);
    }

    function privateBorrow(
        uint256 amount,
        uint256[8] calldata proof,
        uint256[4] calldata pubSignals
    ) external {
        require(verifier.verifyProof(proof, pubSignals), "Invalid borrow proof");

        dscEngine.mintDscFor(amount, msg.sender);

        emit PrivateBorrow(msg.sender, amount);
    }
}