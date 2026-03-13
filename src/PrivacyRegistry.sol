// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {MerkleTreeManager} from "src/MerkleTreeManager.sol";

/**
 * @title PrivacyRegistry
 * @dev Registry for privacy users and Merkle roots
 */
contract PrivacyRegistry {
    MerkleTreeManager public merkleTree;

    mapping(address => bool) public isRegistered;
    mapping(address => uint256) public userIndex;

    event UserRegistered(address indexed user, uint256 index);

    constructor(address _merkleTree) {
        merkleTree = MerkleTreeManager(_merkleTree);
    }

    function registerUser(uint256 commitment) external {
        require(!isRegistered[msg.sender], "Already registered");

        merkleTree.insertLeaf(commitment);
        // Placeholder: set index using block timestamp as pseudo-index
        uint256 index = block.timestamp;
        userIndex[msg.sender] = index;
        isRegistered[msg.sender] = true;

        emit UserRegistered(msg.sender, index);
    }

    function getMerkleRoot(uint256 groupId) external view returns (uint256) {
        return merkleTree.getRoot(groupId);
    }
}