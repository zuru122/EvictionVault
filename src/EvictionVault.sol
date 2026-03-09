// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interface/IEVictionVault.sol";
import "./base/MultiSig.sol";
import "./base/MerkleDistributor.sol";
import "./base/Pausable.sol";
import "./librarirs/SignatureVerifier.sol";

contract EvictionVault is IEvictionVault, MultiSig, MerkleDistributor, Pausable {
    // Added a safe address so that in situation of emergency withdrawal, the asset can be withdrawn to a safe address instead of the owner address which can be compromised.
    address public immutable safeAddress;

    mapping(address => uint256) public balances;

    mapping(bytes32 => bool) public usedHashes;

    uint256 public totalVaultValue;

    constructor(address[] memory _owners, uint256 _threshold) payable {
        _initOwners(_owners, _threshold);
        totalVaultValue = msg.value;
        // used the deployer address as the safe address, for this case, I honestly can't think of a better way yet!
        safeAddress = msg.sender;
    }

    // change the tx.origin to msg.sender.
    receive() external payable {
        balances[msg.sender] += msg.value;
        totalVaultValue += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function deposit() external payable {
        balances[msg.sender] += msg.value;
        totalVaultValue += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        require(!paused, "paused");
        require(balances[msg.sender] >= amount);
        balances[msg.sender] -= amount;
        totalVaultValue -= amount;

        // Using call instead of transfer to avoid gas limit issues
        (bool success,) = payable(msg.sender).call{value: amount}("");
        require(success, "withdrawal failed");

        emit Withdrawal(msg.sender, amount);
    }

    function submitTransaction(address to, uint256 value, bytes calldata data) external {
        require(!paused);
        require(isOwner[msg.sender]);
        uint256 id = _submitTransaction(to, value, data);
        emit Submission(id);
    }

    function confirmTransaction(uint256 txId) external {
        require(!paused);
        require(isOwner[msg.sender]);
        _confirmTransaction(txId);
        emit Confirmation(txId, msg.sender);
    }

    function executeTransaction(uint256 txId) external {
        Transaction storage txn = _executeTransaction(txId);
        (bool s,) = txn.to.call{value: txn.value}(txn.data);
        require(s);
        emit Execution(txId);
    }

    function setMerkleRoot(bytes32 root) external onlyOwner {
        _setMerkleRoot(root);
        emit MerkleRootSet(root);
    }

    function claim(bytes32[] calldata proof, uint256 amount) external {
        require(!paused);
        totalVaultValue -= amount;
        _claim(msg.sender, proof, amount);
        emit Claim(msg.sender, amount);
    }

    // fixed: was using MerkleProof.recover which doesn't exist — moved to ECDSA via SignatureVerifier library
    function verifySignature(address signer, bytes32 messageHash, bytes memory signature) external pure returns (bool) {
        return SignatureVerifier.verify(signer, messageHash, signature);
    }

    // any one can withdraw the asset hence this need an access control
    // Hence I will need to add not just an onlyOwner modifier but onlyOwners since it's multisig.
    function emergencyWithdrawAll() external onlyOwner {
        require(!paused, "paused");
        uint256 prevBalance = address(this).balance;
        _voteEmergency(msg.sender, safeAddress);
        if (address(this).balance < prevBalance) {
            totalVaultValue = 0;
        }
    }

    function pause() external {
        require(isOwner[msg.sender]);
        _pause(msg.sender, threshold);
    }

    function unpause() external {
        require(isOwner[msg.sender]);
        _unpause(msg.sender, threshold);
    }
}
