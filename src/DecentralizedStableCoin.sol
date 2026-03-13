// SPDX-License-Identifier: MIT

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.30;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/*
 * @title DecentralizedStableCoin                               (去中心化稳定币)
 * @author Maxence90
 * Collateral: Exogenous (ETH & BTC)
 * Minting (Stability Mechanism): Decentralized (Algorithmic)   (铸造:去中心化型)
 * Value (Relative Stability): Anchored (Pegged to USD)         (价值:锚定,与美元挂钩)
 * Collateral Type: Crypto                                      (抵押品类型: 加密货币)
 *
 * This is the contract meant to be owned by DSCEngine. It is an ERC20 token that can be minted and burned by the DSCEngine smart contract.
 * (本合约为 DSCEngine 所有。它是一种 ERC20 代币，可由 DSCEngine 智能合约进行铸造和销毁。)
 *
 */

contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    error DecentralizedStableCoin_MustBeMoreThanZero();
    error DecentralizedStableCoin_BrunAmountExceedsBalance();
    error DecentralizedStableCoin_NotZeroAddress();
    error DecentralizedStableCoin_InsufficientAllowance();

    constructor() ERC20("DecentralizedStableCoin", "DSC") Ownable(msg.sender) {}

    // 销毁
    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert DecentralizedStableCoin_MustBeMoreThanZero();
        }
        if (balance < _amount) {
            revert DecentralizedStableCoin_BrunAmountExceedsBalance();
        }
        super.burn(_amount);
    }

    // 销毁他人的代币（需要授权）
    function burnFrom(address _account, uint256 _amount) public override onlyOwner {
        uint256 currentAllowance = allowance(_account, msg.sender);
        if (currentAllowance < _amount) {
            revert DecentralizedStableCoin_InsufficientAllowance();
        }
        if (_amount <= 0) {
            revert DecentralizedStableCoin_MustBeMoreThanZero();
        }
        super.burnFrom(_account, _amount);
    }

    //铸造
    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DecentralizedStableCoin_NotZeroAddress();
        }
        if (_amount <= 0) {
            revert DecentralizedStableCoin_MustBeMoreThanZero();
        }
        _mint(_to, _amount);
        return true;
    }

    // 隐私转账 (使用ZK证明)
    function privateTransfer(
        address _to,
        uint256 _amount,
        bytes memory proof // Placeholder for ZK proof
    ) external {
        // In a real implementation, verify ZK proof here
        // For now, just perform normal transfer
        _transfer(msg.sender, _to, _amount);
    }
}
