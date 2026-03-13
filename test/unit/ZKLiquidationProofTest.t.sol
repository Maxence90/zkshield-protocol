// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {ZKLiquidationProof} from "src/ZKLiquidationProof.sol";
import {ZKVerifier} from "src/ZKVerifier.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract ZKLiquidationProofTest is Test {
    ZKLiquidationProof liquidationProof;
    ZKVerifier verifier;
    DSCEngine engine;
    DecentralizedStableCoin dsc;
    address[] tokenAddresses;
    address[] priceFeedAddresses;

    function setUp() public {
        verifier = new ZKVerifier();
        dsc = new DecentralizedStableCoin();

        // Setup mock tokens and feeds
        MockV3Aggregator ethFeed = new MockV3Aggregator(8, 2000e8);
        MockV3Aggregator btcFeed = new MockV3Aggregator(8, 1000e8);
        ERC20Mock weth = new ERC20Mock();
        ERC20Mock wbtc = new ERC20Mock();

        tokenAddresses = [address(weth), address(wbtc)];
        priceFeedAddresses = [address(ethFeed), address(btcFeed)];

        engine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc), address(verifier));
        liquidationProof = new ZKLiquidationProof(address(verifier), address(engine));
    }

    function testSubmitLiquidationProof_EmitsEvent() public {
        uint256[8] memory proof = [uint256(1), 2, 3, 4, 5, 6, 7, 8];
        uint256[4] memory pubSignals = [uint256(2e18), 0, 0, 0]; // Health factor > 1

        vm.expectEmit(true, false, false, false);
        emit ZKLiquidationProof.LiquidationPrevented(address(this), 2e18);

        liquidationProof.submitLiquidationProof(proof, pubSignals);
    }
}