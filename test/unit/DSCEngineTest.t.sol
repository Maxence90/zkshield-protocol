// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig config;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;

    address public USER = makeAddr("user");
    address public LIQUIDATOR = makeAddr("liquidator");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;
    uint256 public constant STARTING_AMOUNT_DSC_TO_MINT = 10 ether;
    uint256 public constant AMOUNT_DENGEROUS_MINT_DSC = 9000 ether;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsce) = deployer.run();
        config = deployer.config();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth,,) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
        ERC20Mock(weth).mint(LIQUIDATOR, STARTING_ERC20_BALANCE);

        vm.prank(address(dsce)); // 以 DSCEngine 的身份（因为只有 owner 可以 mint）
        dsc.mint(LIQUIDATOR, 20000 ether); // 铸造足够的 DSC 用于清算
    }
    ///////////////////////
    // Constructor Tests///
    ///////////////////////
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenLengthDoesntMatchPriceeFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine_TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc), address(0));
    }

    ///////////////////////
    // Price Test       ///
    ///////////////////////

    function testGetUsdValue() public {
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = dsce.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    function testGetTokenAmountFromUsd() public {
        uint256 usdAmount = 100 ether;
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = dsce.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedWeth, actualWeth);
    }

    ///////////////////////////////
    // depositCollateral Tests  ///
    ///////////////////////////////

    function testRevertsIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine_NeedsMoreThanZero.selector);
        dsce.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock ranToken = new ERC20Mock();
        ranToken.mint(USER, AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine_NotAllowedToken.selector);
        dsce.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }
    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(USER);
        uint256 expectedTotalDscMinted = 0;
        uint256 expectedDepositAmount = dsce.getTokenAmountFromUsd(weth, collateralValueInUsd); //用户抵押的代币美元额度
        assertEq(totalDscMinted, expectedTotalDscMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount);
    }

    function testDepositCollateralAndMintDsc_WithValidInputs_Success() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, STARTING_AMOUNT_DSC_TO_MINT);
        vm.stopPrank();
        (uint256 AmountDscMinted,) = dsce.getAccountInformation(USER);

        assertEq(STARTING_AMOUNT_DSC_TO_MINT, AmountDscMinted);
    }

    //@TODO 模糊匹配
    // function testMintDsc_WithNotEnoughtCollateral_Revert() public depositedCollateral {
    //     vm.startPrank(USER);
    //     vm.expectRevert(DSCEngine.DSCEngie_BreaksHealthFactor.selector);
    //     dsce.mintDsc(AMOUNT_EXCESS_MINT_DSC);
    //     vm.stopPrank();
    // }

    /////////////////////////////
    // RedeemCollateral Test  ///
    /////////////////////////////
    modifier depositedCollateralAndMintDsc() {
        vm.startPrank(USER);
        dsc.approve(address(dsce), STARTING_AMOUNT_DSC_TO_MINT);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, STARTING_AMOUNT_DSC_TO_MINT);
        vm.stopPrank();
        _;
    }

    function testRedeemCollateral_WithSufficientBalance_ReturnsCollateral() public depositedCollateralAndMintDsc {
        vm.startPrank(USER);
        dsce.redeemCollateral(weth, AMOUNT_COLLATERAL / 2);

        uint256 expectTotalCollateral = AMOUNT_COLLATERAL - AMOUNT_COLLATERAL / 2;
        uint256 actualTotalCollateral = dsce.getOneAccountCollateral(weth);
        vm.stopPrank();

        assertEq(expectTotalCollateral, actualTotalCollateral);
    }

    function testRedeemCollateral_WithHaveNotEnoughCollateral_Reverts() public depositedCollateralAndMintDsc {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngie_NotEnoughCollateral.selector);

        dsce.redeemCollateral(weth, AMOUNT_COLLATERAL * 2);
        vm.stopPrank();
    }

    /////////////////////////////
    // BurnDsc Test           ///
    /////////////////////////////

    function testBurnDsc_WithValidInputs_Success() public depositedCollateralAndMintDsc {
        vm.startPrank(USER);
        dsc.approve(address(dsce), STARTING_AMOUNT_DSC_TO_MINT);
        dsce.burnDsc(STARTING_AMOUNT_DSC_TO_MINT);

        uint256 expectAccountDsc = 0;
        uint256 actualAccountDsc = dsce.getOneAccountMintedDsc();

        assertEq(expectAccountDsc, actualAccountDsc);
    }

    function testBurnDsc_WithTooMuchAmountToken_Reverts() public depositedCollateralAndMintDsc {
        vm.startPrank(USER);
        dsc.approve(address(dsce), STARTING_AMOUNT_DSC_TO_MINT * 2);

        vm.expectRevert(DSCEngine.DSCEngie_NotEnoughDSC.selector);
        dsce.burnDsc(STARTING_AMOUNT_DSC_TO_MINT * 2);
        vm.stopPrank();
    }

    function testRedeemCollateralForDsc_withValidInputs_Success() public depositedCollateralAndMintDsc {
        vm.startPrank(USER);
        dsce.redeemCollateralForDsc(weth, AMOUNT_COLLATERAL / 2, STARTING_AMOUNT_DSC_TO_MINT / 2);

        uint256 actualAmountCollateral = dsce.getOneAccountCollateral(weth);
        uint256 actualAmountMintedDsc = dsce.getOneAccountMintedDsc();
        vm.stopPrank();
        uint256 expectAmountCollateral = AMOUNT_COLLATERAL - AMOUNT_COLLATERAL / 2;
        uint256 expectAmountMintedDsc = STARTING_AMOUNT_DSC_TO_MINT - STARTING_AMOUNT_DSC_TO_MINT / 2;

        assertEq(actualAmountCollateral, expectAmountCollateral);
        assertEq(expectAmountMintedDsc, actualAmountMintedDsc);
    }

    ///////////////////////
    // HealthFactor Test///
    ///////////////////////
    function testGetHealthFactor_WithValidInputs_Success() public depositedCollateralAndMintDsc {
        uint256 healthFactor = dsce.getHealthFactor(USER);
        uint256 MIN_HEALTH_FACTOR = 1e18;

        assert(healthFactor >= MIN_HEALTH_FACTOR);
    }

    ///////////////////////
    // Liquidate Test   ///
    ///////////////////////
    modifier depositedCollateralAndMintDscWithDengrous() {
        vm.startPrank(USER);
        dsc.approve(address(dsce), STARTING_AMOUNT_DSC_TO_MINT);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_DENGEROUS_MINT_DSC);
        vm.stopPrank();
        _;
    }

    modifier LiquidatorDepositedCollateral() {
        uint256 debtToCover = 13000 ether; // 要清算的债务金额
        vm.startPrank(LIQUIDATOR);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsc.approve(address(dsce), debtToCover);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testLiquidate_WithHealthUser_Revert() public depositedCollateralAndMintDsc {
        uint256 debtToCover = 13000 ether;

        vm.startPrank(LIQUIDATOR);
        vm.expectRevert(DSCEngine.DSCEngie_HealthFactorOk.selector);
        dsce.liquidate(weth, USER, debtToCover);
        vm.stopPrank();
    }

    function testLiquidate_WithValidInputs_Success()
        public
        depositedCollateralAndMintDscWithDengrous
        LiquidatorDepositedCollateral
    {
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(1000e8);
        uint256 debtToCover = 13000 ether;

        vm.startPrank(LIQUIDATOR);
        dsce.liquidate(weth, USER, debtToCover);
        vm.stopPrank();

        uint256 expectAccountUSERCollateral = 0.1 ether;
        uint256 expectAccountUSERMintedDsc = 0;
        vm.startPrank(USER);
        uint256 actualAccountUSERCollateral = dsce.getOneAccountCollateral(weth);
        uint256 actualAccountUSERMintedDsc = dsce.getOneAccountMintedDsc();
        vm.stopPrank();

        assertEq(expectAccountUSERCollateral, actualAccountUSERCollateral);
        assertEq(expectAccountUSERMintedDsc, actualAccountUSERMintedDsc);
    }

    function testLiquidate_WithExcessUserCollateral_Success()
        public
        depositedCollateralAndMintDscWithDengrous
        LiquidatorDepositedCollateral
    {
        uint256 debtToCover = 13000 ether; // 愿意付出的dsc

        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(1e8);

        vm.startPrank(LIQUIDATOR);
        dsce.liquidate(weth, USER, debtToCover);
        vm.stopPrank();

        uint256 expectAccountUSERCollateral = 0;
        uint256 expectAccountUSERMintedDsc = 0;
        vm.startPrank(USER);
        uint256 actualAccountUSERCollateral = dsce.getOneAccountCollateral(weth);
        uint256 actualAccountUSERMintedDsc = dsce.getOneAccountMintedDsc();
        vm.stopPrank();

        assertEq(expectAccountUSERCollateral, actualAccountUSERCollateral);
        assertEq(expectAccountUSERMintedDsc, actualAccountUSERMintedDsc);
    }

    function testLiquidate_WithLiquidatorHaveNotEnoughDsc_Revert() public depositedCollateralAndMintDscWithDengrous {
        uint256 debtToCover = 100 ether; // 愿意付出的dsc
        vm.startPrank(LIQUIDATOR);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsc.approve(address(dsce), debtToCover);
        vm.stopPrank();

        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(1e8);

        vm.startPrank(LIQUIDATOR);
        vm.expectRevert(DSCEngine.DSCEngie_HealthFactorNotImproved.selector);
        dsce.liquidate(weth, USER, debtToCover);
        vm.stopPrank();
    }

    //返回ERC20的错误
    // function testLiquidate_WithLiquidatorNotAuthorize_Revert() public depositedCollateralAndMintDscWithDengrous {
    //     uint256 debtToCover = 13000 ether; // 要清算的债务金额
    //     vm.startPrank(LIQUIDATOR);
    //     ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
    //     dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
    //     vm.stopPrank();

    //     MockV3Aggregator(ethUsdPriceFeed).updateAnswer(1000e8);

    //     vm.startPrank(LIQUIDATOR);
    //     vm.expectRevert("ERC20: insufficient allowance");
    //     dsce.liquidate(weth, USER, debtToCover);
    //     vm.stopPrank();
    // }
}
