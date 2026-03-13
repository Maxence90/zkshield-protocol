// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ZKVerifier} from "src/ZKVerifier.sol";
import {MerkleTreeManager} from "src/MerkleTreeManager.sol";
import {ZKLiquidationProof} from "src/ZKLiquidationProof.sol";
import {ZKMEVAuction} from "src/ZKMEVAuction.sol";
import {ZKCreditScore} from "src/ZKCreditScore.sol";
import {PrivateLendingCore} from "src/PrivateLendingCore.sol";
import {PrivacyRegistry} from "src/PrivacyRegistry.sol";

contract DeployDSC is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;
    HelperConfig public config;

    function run() external returns (DecentralizedStableCoin, DSCEngine) {
        config = new HelperConfig();
        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address weth, address wbtc, uint256 deployerKey) =
            config.activeNetworkConfig();

        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];
        tokenAddresses = [weth, wbtc];

        vm.startBroadcast(deployerKey);
        DecentralizedStableCoin dsc = new DecentralizedStableCoin();

        // Deploy ZK components
        ZKVerifier verifier = new ZKVerifier();
        MerkleTreeManager merkleTree = new MerkleTreeManager();
        PrivacyRegistry registry = new PrivacyRegistry(address(merkleTree));

        DSCEngine engine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc), address(verifier));

        ZKLiquidationProof liquidationProof = new ZKLiquidationProof(address(verifier), address(engine));
        ZKMEVAuction mevAuction = new ZKMEVAuction(address(verifier), address(dsc));
        ZKCreditScore creditScore = new ZKCreditScore(address(verifier), address(merkleTree));
        PrivateLendingCore lendingCore = new PrivateLendingCore(address(engine), address(dsc), address(verifier));

        dsc.transferOwnership(address(engine));
        vm.stopBroadcast();

        return (dsc, engine);
    }
}
