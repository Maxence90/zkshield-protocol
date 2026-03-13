// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {PrivacyRegistry} from "src/PrivacyRegistry.sol";
import {MerkleTreeManager} from "src/MerkleTreeManager.sol";

contract PrivacyRegistryTest is Test {
    PrivacyRegistry registry;
    MerkleTreeManager merkleTree;

    function setUp() public {
        merkleTree = new MerkleTreeManager();
        registry = new PrivacyRegistry(address(merkleTree));
    }

    function testRegisterUser_EmitsEvent() public {
        uint256 commitment = 12345;

        vm.expectEmit(true, false, false, false);
        emit PrivacyRegistry.UserRegistered(address(this), block.timestamp);

        registry.registerUser(commitment);
    }

    function testRegisterUser_SetsRegistered() public {
        uint256 commitment = 67890;

        registry.registerUser(commitment);

        assertTrue(registry.isRegistered(address(this)));
        assertEq(registry.userIndex(address(this)), block.timestamp);
    }

    function testGetMerkleRoot_ReturnsRoot() public {
        uint256 commitment = 11111;
        registry.registerUser(commitment);

        uint256 root = registry.getMerkleRoot(0); // Assuming groupId 0
        assertTrue(root != 0); // Root should be set after insertion
    }
}