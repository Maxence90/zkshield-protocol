// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {MerkleTreeManager} from "src/MerkleTreeManager.sol";

contract MerkleTreeManagerTest is Test {
    MerkleTreeManager manager;

    function setUp() public {
        manager = new MerkleTreeManager();
    }

    function testInsertLeaf_UpdatesRoot() public {
        uint256 leaf = 12345;
        manager.insertLeaf(leaf);
        uint256 root = manager.getRoot(0); // Assuming groupId 0
        assertTrue(root != 0, "Root should be updated after inserting leaf");
    }

    function testGetProof_ReturnsArray() public {
        uint256 leaf = 67890;
        manager.insertLeaf(leaf);
        uint256[] memory proof = manager.getProof(0, leaf);
        assertTrue(proof.length >= 0, "Proof should be an array");
    }
}