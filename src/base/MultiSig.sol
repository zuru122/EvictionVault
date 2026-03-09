// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract MultiSig {
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
        uint256 submissionTime;
        uint256 executionTime;
    }

    uint256 public constant TIMELOCK_DURATION = 1 hours;

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public threshold;

    mapping(uint256 => mapping(address => bool)) public confirmed;
    mapping(uint256 => Transaction) public transactions;
    uint256 public txCount;

    uint256 emergencyConfirmations;
    mapping(address => bool) public emergencyVotes;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    function _initOwners(address[] memory _owners, uint256 _threshold) internal {
        require(_owners.length > 0, "no owners");
        threshold = _threshold;
        for (uint256 i = 0; i < _owners.length; i++) {
            address o = _owners[i];
            require(o != address(0));
            isOwner[o] = true;
            owners.push(o);
        }
    }

    function _submitTransaction(address to, uint256 value, bytes calldata data) internal returns (uint256 id) {
        id = txCount++;
        transactions[id] = Transaction({
            to: to,
            value: value,
            data: data,
            executed: false,
            confirmations: 1,
            submissionTime: block.timestamp,
            executionTime: 0
        });
        confirmed[id][msg.sender] = true;
    }

    function _confirmTransaction(uint256 txId) internal {
        Transaction storage txn = transactions[txId];
        require(!txn.executed);
        require(!confirmed[txId][msg.sender]);
        confirmed[txId][msg.sender] = true;
        txn.confirmations++;
        if (txn.confirmations == threshold) {
            txn.executionTime = block.timestamp + TIMELOCK_DURATION;
        }
    }

    function _executeTransaction(uint256 txId) internal returns (Transaction storage txn) {
        txn = transactions[txId];
        require(txn.confirmations >= threshold);
        require(!txn.executed);
        require(txn.executionTime > 0, "timelock not started");
        require(block.timestamp >= txn.executionTime);
        txn.executed = true;
    }

    function _voteEmergency(address voter, address safeAddress) internal {
        require(!emergencyVotes[voter], "already voted");
        emergencyVotes[voter] = true;
        emergencyConfirmations++;
        if (emergencyConfirmations >= threshold) {
            uint256 amount = address(this).balance;
            (bool success,) = payable(safeAddress).call{value: amount}("");
            require(success, "transfer failed");
        }
    }
}
