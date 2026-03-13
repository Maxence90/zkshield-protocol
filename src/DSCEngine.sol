// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "chainlink-evm/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {console} from "forge-std/console.sol";
import {OracleLib} from "src/libraries/OracleLib.sol";
import {ZKVerifier} from "src/ZKVerifier.sol";
/**
 * @title DSCEngie
 * @author Maxence90
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all times.
 * This is a stablecoin with the properties:
 * - Exogenously Collateralized
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was backed by only WETH and WBTC.
 *
 * Our DSC system should always be "overcollateralized". At no point, should the value of
 * all collateral < the $ backed value of all the DSC.
 *
 * @notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic
 * for minting and redeeming DSC, as well as depositing and withdrawing collateral.
 * @notice This contract is based on the MakerDAO DSS system
 *
 * Chinese:
 *
 * 本系统设计力求极简，确保代币始终维持 1 代币 = 1 美元的挂钩汇率。
 * 这是一种稳定币，具有以下特性：
 * - 外部抵押型
 * - 与美元挂钩
 * - 算法稳定型
 * 它类似于 DAI，但没有治理机制、没有手续费，且仅由 WETH 和 WBTC 作为抵押品。
 * 我们的 DSC 系统应始终保持 “超额抵押” 状态。在任何情况下，所有抵押品的价值都不应低于所有 DSC 的美元支持价值。
 * @notice 本合约是去中心化稳定币系统的核心。它负责处理 DSC 的铸造与赎回，以及抵押品的存入与提取等所有逻辑。
 * @notice 本合约基于 MakerDAO 的 DSS 系统开发
 *
 */

contract DSCEngine is ReentrancyGuard {
    ////////////////////
    // Error         ///
    ////////////////////
    error DSCEngine_NeedsMoreThanZero();
    error DSCEngine_TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    error DSCEngine_NotAllowedToken();
    error DSCEngine_TransferFailed();
    error DSCEngie_BreaksHealthFactor(uint256 healthFactor);
    error DSCEngie_MintFailed();
    error DSCEngie_NotEnoughCollateral();
    error DSCEngie_NotEnoughDSC();
    error DSCEngie_HealthFactorOk();
    error DSCEngie_HealthFactorNotImproved();
    error DSCEngine_InvalidPrice();

    ///////////////////////
    // Type             ///
    ///////////////////////
    using OracleLib for AggregatorV3Interface;

    ///////////////////////
    // State Variables  ///
    ///////////////////////
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONS = 10;

    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountDscMinted) private s_DSCMinted;
    address[] private s_collateralTokens;

    DecentralizedStableCoin private immutable i_dsc;
    ZKVerifier public zkVerifier; // ZK verifier for privacy features

    ///////////////////////
    // Events           ///
    ///////////////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(
        address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount
    );

    ////////////////////
    // Modifier      ///
    ////////////////////
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine_NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine_NotAllowedToken();
        }
        _;
    }

    ////////////////////
    // Function      ///
    ////////////////////
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddress, address dscAddress, address _zkVerifier) {
        if (tokenAddresses.length != priceFeedAddress.length) {
            revert DSCEngine_TokenAddressesAndPriceFeedAddressesMustBeSameLength();
        }
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddress[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
        zkVerifier = ZKVerifier(_zkVerifier);
    }

    /////////////////////////////
    // External Function      ///
    /////////////////////////////

    /**
     * @notice follows CEI
     * @param amountDscToMint The amount of decentralized stablecoin to mint
     * @param onBehalfOf The user to mint for
     * @notice they must have more collateral value than the minimun thershold
     */
    function mintDscFor(uint256 amountDscToMint, address onBehalfOf) public moreThanZero(amountDscToMint) nonReentrant {
        s_DSCMinted[onBehalfOf] += amountDscToMint;
        _revertIfHealthFactorIsBroken(onBehalfOf);
        bool minted = i_dsc.mint(onBehalfOf, amountDscToMint);
        if (!minted) {
            revert DSCEngie_MintFailed();
        }
    }

    //销毁DSC并赎回抵押品
    function redeemCollateralForDsc(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToBurn)
        external
    {
        burnDsc(amountDscToBurn);
        redeemCollateral(tokenCollateralAddress, amountCollateral);
    }

    /**
     *
     * @param collateral The erc20 collateral address to liquidate from the user
     * @param user The user who has broken the health factor. Their _healthFactor should be below MIN_HEALTH_FACTOR
     * @param debtToCover The amount of DSC you want to burn to imporve the users health factor
     * @notice You can partially liquidate a user
     * @notice You will get a liquidation bonus for taking the users funds
     * @notice This function working assumes the protocol will be roughly 200% overcollateralized in order for this to work
     *
     */
    function liquidate(address collateral, address user, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
        nonReentrant
    {
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngie_HealthFactorOk();
        }

        uint256 userDebt = s_DSCMinted[user];
        if (debtToCover > userDebt) {
            debtToCover = userDebt;
        }
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);

        uint256 bounsCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONS) / LIQUIDATION_PRECISION; // * 0.1,用作奖励

        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bounsCollateral;
        // 不能赎回超过用户实际拥有的抵押品
        uint256 userCollateralBalance = s_collateralDeposited[user][collateral];
        if (totalCollateralToRedeem > userCollateralBalance) {
            totalCollateralToRedeem = userCollateralBalance;
        }

        _redeemCollateral(collateral, totalCollateralToRedeem, user, msg.sender);
        _burnDsc(debtToCover, user, msg.sender);

        uint256 endingUserHealthFactor = _healthFactor(user);
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert DSCEngie_HealthFactorNotImproved();
        }
    }

    ////////////////////////////////////
    // Private & Internal Functions  ///
    ////////////////////////////////////

    /**
     * @dev Low-level internal function, do not call unless the function calling it is
     * checking for health
     */
    function _burnDsc(uint256 amountDscToBurn, address onBehalfOf, address dscFrom) private {
        s_DSCMinted[onBehalfOf] -= amountDscToBurn;
        bool success = i_dsc.transferFrom(dscFrom, address(this), amountDscToBurn);
        require(success, DSCEngine_TransferFailed());
        i_dsc.burn(amountDscToBurn);
    }

    function _redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral, address from, address to)
        private
    {
        // 添加检查
        if (s_collateralDeposited[from][tokenCollateralAddress] < amountCollateral) {
            revert DSCEngie_NotEnoughCollateral();
        }
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if (!success) {
            revert DSCEngine_TransferFailed();
        }
    }

    //获得用户铸造稳定币总量和抵押物价值
    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        totalDscMinted = s_DSCMinted[user];
        collateralValueInUsd = getAccountCollaterValue(user);
    }

    //判断用户的抵押物品价值是否超过铸造的代币价值
    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        if (totalDscMinted == 0) {
            return type(uint256).max;
        }
        uint256 collateralAdjustForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION; //也就是*0.5
        return ((collateralAdjustForThreshold * PRECISION) / totalDscMinted);
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngie_BreaksHealthFactor(userHealthFactor);
        }
    }

    ////////////////////////////////////
    // Public & Internal Functions  ///
    ////////////////////////////////////
    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.staleCheckLastestRoundData();
        if (price <= 0) {
            revert DSCEngine_InvalidPrice();
        }
        return (usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    function getAccountCollaterValue(address user) public view returns (uint256) {
        uint256 totalCollaterValueInUsd = 0;
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollaterValueInUsd += getUsdValue(token, amount);
        }
        return totalCollaterValueInUsd;
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.staleCheckLastestRoundData();
        return (uint256(price) * ADDITIONAL_FEED_PRECISION * amount) / PRECISION;
    }

    /*
     * @param tokenCollateralAddress Address of the collateral to deposit
     * @param amountCollateral The amount of collateral to deposit
     * 大多数涉及外部调用的函数默认都存在重入风险，因此需要主动使用 nonReentrant 等防护措施。虽然这会消耗少量Gas，但为了安全是值得的
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine_TransferFailed();
        }
    }

    /**
     * @notice follows CEI
     * @param amountDscToMint The amount of decentralized stablecoin to mint
     * @notice they must have more collateral value than the minimun thershold
     */
    function mintDsc(uint256 amountDscToMint) public moreThanZero(amountDscToMint) nonReentrant {
        mintDscFor(amountDscToMint, msg.sender);
    }

    // 赎回抵押品
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateralToRedeem)
        public
        moreThanZero(amountCollateralToRedeem)
        nonReentrant
    {
        if (s_collateralDeposited[msg.sender][tokenCollateralAddress] < amountCollateralToRedeem) {
            revert DSCEngie_NotEnoughCollateral();
        }
        _redeemCollateral(tokenCollateralAddress, amountCollateralToRedeem, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    // 销毁
    function burnDsc(uint256 amount) public moreThanZero(amount) {
        if (s_DSCMinted[msg.sender] < amount) {
            revert DSCEngie_NotEnoughDSC();
        }
        _burnDsc(amount, msg.sender, msg.sender);
    }

    /////////////////////////////
    //view & pure functions   ///
    /////////////////////////////
    function getOneAccountCollateral(address tokenCollateralAddress) external view returns (uint256) {
        return s_collateralDeposited[msg.sender][tokenCollateralAddress];
    }

    function getOneAccountMintedDsc() external view returns (uint256) {
        return s_DSCMinted[msg.sender];
    }

    function getCollateralTokenPriceFeed(address token) external view returns (address) {
        return s_priceFeeds[token];
    }

    function getCollateralToken() external view returns (address[] memory) {
        return s_collateralTokens;
    }

    function getCollateralBalanceOfUser(address user, address token) external view returns (uint256) {
        return s_collateralDeposited[user][token];
    }

    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }

    function getLiquidationThreshold() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD * PRECISION / LIQUIDATION_PRECISION;
    }

    function getAccountInformation(address user)
        external
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        (totalDscMinted, collateralValueInUsd) = _getAccountInformation(user);
    }

    /**
     *
     * @param tokenCollateralAddress The address of the token to deposit as collateral
     * @param amountCollateral The amount of collateral to deposit
     * @param amountDscToMint  The amount of Dsc(decentralized stablecoin) to Mint
     * @notice this function will deposit your collateral and mint DSC in one transaction
     */
    function depositCollateralAndMintDsc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDscFor(amountDscToMint, msg.sender);
    }

    function depositCollateralAndMintDscWithProof(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint,
        uint256[8] calldata proof,
        uint256[4] calldata pubSignals
    ) external {
        require(zkVerifier.verifyProof(proof, pubSignals), "Invalid deposit proof");
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDscFor(amountDscToMint, msg.sender);
    }
}
