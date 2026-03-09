// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../lib/openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";

abstract contract MerkleDistributor {
    bytes32 public merkleRoot;
    mapping(address => bool) public claimed;

    function _setMerkleRoot(bytes32 root) internal {
        merkleRoot = root;
    }

    function _claim(address claimant, bytes32[] calldata proof, uint256 amount) internal {
        bytes32 leaf = keccak256(abi.encodePacked(claimant, amount));
        bytes32 computed = MerkleProof.processProof(proof, leaf);
        require(computed == merkleRoot);
        require(!claimed[claimant]);
        claimed[claimant] = true;
        (bool success,) = payable(claimant).call{value: amount}("");
        require(success, "withdrawal failed");
    }
}
