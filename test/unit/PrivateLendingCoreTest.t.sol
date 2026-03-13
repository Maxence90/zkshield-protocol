// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {PrivateLendingCore} from "src/PrivateLendingCore.sol";
import {ZKVerifier} from "src/ZKVerifier.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract PrivateLendingCoreTest is Test {
    PrivateLendingCore lendingCore;
    ZKVerifier verifier;
    DSCEngine engine;
    DecentralizedStableCoin dsc;
    address[] tokenAddresses;
    address[] priceFeedAddresses;
    ERC20Mock weth;

    function setUp() public {
        verifier = new ZKVerifier();
        dsc = new DecentralizedStableCoin();

        // Setup mock tokens and feeds
        vm.warp(100000); // Set block timestamp before creating feed
        MockV3Aggregator ethFeed = new MockV3Aggregator(8, 2000e8);
        ERC20Mock wbtc = new ERC20Mock();
        weth = new ERC20Mock();

        tokenAddresses = [address(weth), address(wbtc)];
        priceFeedAddresses = [address(ethFeed), address(ethFeed)]; // Simplified

        engine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc), address(verifier));
        
        // Transfer ownership of DSC to engine so it can mint
        dsc.transferOwnership(address(engine));
        
        lendingCore = new PrivateLendingCore(address(engine), address(dsc), address(verifier));
    }

    function testPrivateDeposit_Works() public {
        uint256[8] memory proof = [uint256(1), 2, 3, 4, 5, 6, 7, 8];
        uint256[4] memory pubSignals = [uint256(1 ether), 0, 0, 0];

        // Mint some tokens to this contract and approve lendingCore
        weth.mint(address(this), 1 ether);
        weth.approve(address(lendingCore), 1 ether);

        uint256 balanceBefore = weth.balanceOf(address(this));
        lendingCore.privateDeposit(address(weth), 1 ether, proof, pubSignals);
        uint256 balanceAfter = weth.balanceOf(address(this));

        assertEq(balanceBefore - balanceAfter, 1 ether, "Tokens should be transferred");
    }

    function testPrivateBorrow_Works() public {
        uint256[8] memory proof = [uint256(1), 2, 3, 4, 5, 6, 7, 8];
        uint256[4] memory pubSignals = [uint256(100), 0, 0, 0];

        // First deposit collateral to have good health factor
        weth.mint(address(this), 10 ether);
        weth.approve(address(engine), 10 ether);
        engine.depositCollateral(address(weth), 10 ether);

        uint256 dscBalanceBefore = dsc.balanceOf(address(this));
        lendingCore.privateBorrow(100, proof, pubSignals);
        uint256 dscBalanceAfter = dsc.balanceOf(address(this));

        assertEq(dscBalanceAfter - dscBalanceBefore, 100, "DSC should be minted");
    }
}