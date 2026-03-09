// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

library SignatureVerifier {
    function verify(address signer, bytes32 messageHash, bytes memory signature) internal pure returns (bool) {
        return ECDSA.recover(messageHash, signature) == signer;
    }
}
