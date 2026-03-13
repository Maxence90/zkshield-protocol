// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";

contract Handler is Test {
    DSCEngine dsce;
    DecentralizedStableCoin dsc;

    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;

    ERC20Mock weth;
    ERC20Mock wbtc;
    address public currentUser = address(this);
    MockV3Aggregator public ethUsdPriceFeed;

    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc) {
        dsce = _dscEngine;
        dsc = _dsc;

        address[] memory collateralTokens = dsce.getCollateralToken();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

        ethUsdPriceFeed = MockV3Aggregator(dsce.getCollateralTokenPriceFeed(address(weth)));
    }

    function mintDsc(uint256 amount) public {
        amount = bound(amount, 1, MAX_DEPOSIT_SIZE);
        vm.startPrank(currentUser);
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(currentUser);
        uint256 maxDscToMinted = (collateralValueInUsd / 2) - totalDscMinted;
        if (maxDscToMinted < 0) {
            return;
        }
        amount = bound(amount, 0, maxDscToMinted);
        if (amount == 0) {
            return;
        }
        dsce.mintDsc(amount);
        vm.stopPrank();
    }

    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);

        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);
        vm.startPrank(currentUser);
        collateral.mint(currentUser, amountCollateral);
        collateral.approve(address(dsce), amountCollateral);

        dsce.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollateralToRedeem = dsce.getCollateralBalanceOfUser(currentUser, address(collateral));
        amountCollateral = bound(amountCollateral, 0, maxCollateralToRedeem);
        if (amountCollateral == 0) {
            return;
        }

        //在赎回前偿还一部分债务，以维持健康因子
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(currentUser);

        // 如果存在债务，则计算需要偿还多少以保持安全
        if (totalDscMinted > 0) {
            // 估算赎回后的健康因子
            // 假设我们希望维持健康因子至少为 1.0
            uint256 collateralValueAfterRedemption =
                collateralValueInUsd - dsce.getUsdValue(address(collateral), amountCollateral);
            uint256 desiredMaxDebt = collateralValueAfterRedemption * dsce.getLiquidationThreshold() / 1e18;

            if (totalDscMinted > desiredMaxDebt) {
                uint256 dscToBurn = totalDscMinted - desiredMaxDebt;
                // 确保用户有足够的 DSC 用于销毁
                dscToBurn = bound(dscToBurn, 0, dsc.balanceOf(currentUser));

                if (dscToBurn > 0) {
                    vm.startPrank(currentUser);
                    dsc.approve(address(dsce), dscToBurn);
                    dsce.burnDsc(dscToBurn);
                    vm.stopPrank();
                }
            }
        }

        vm.startPrank(currentUser);
        dsce.redeemCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
    }

    //破坏了协议
    // function updateCollateralPrice(uint96 newPrice) public {
    //     int256 newPriceInt = int256(uint256(newPrice));
    //     ethUsdPriceFeed.updateAnswer(newPriceInt);
    // }

    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        }
        return wbtc;
    }
}
