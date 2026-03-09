// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "../lib/openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";

contract EvictionVault {
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
        uint256 submissionTime;
        uint256 executionTime;
    }
    // Added a safe address so that in situation of emergency withdrawal, the asset can be withdrawn to a safe address instead of the owner address which can be compromised.
    address public immutable safeAddress;

    address[] public owners;
    mapping(address => bool) public isOwner;

    uint256 public threshold;

    mapping(uint256 => mapping(address => bool)) public confirmed;
    mapping(uint256 => Transaction) public transactions;

    uint256 public txCount;

    mapping(address => uint256) public balances;

    bytes32 public merkleRoot;

    mapping(address => bool) public claimed;

    mapping(bytes32 => bool) public usedHashes;

    uint256 public constant TIMELOCK_DURATION = 1 hours;

    uint256 public totalVaultValue;

    bool public paused;

    event Deposit(address indexed depositor, uint256 amount);
    event Withdrawal(address indexed withdrawer, uint256 amount);
    event Submission(uint256 indexed txId);
    event Confirmation(uint256 indexed txId, address indexed owner);
    event Execution(uint256 indexed txId);
    event MerkleRootSet(bytes32 indexed newRoot);
    event Claim(address indexed claimant, uint256 amount);

    constructor(address[] memory _owners, uint256 _threshold) payable {
        require(_owners.length > 0, "no owners");
        threshold = _threshold;

        for (uint256 i = 0; i < _owners.length; i++) {
            address o = _owners[i];
            require(o != address(0));
            isOwner[o] = true;
            owners.push(o);
        }
        totalVaultValue = msg.value;
        // used the deployer address as the safe address, for this case, I honestly can't think of a better way yet!
        safeAddress = msg.sender;
    }

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
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

        // payable(msg.sender).transfer(amount);
        // Using call instead of transfer to avoid gas limit issues
        (bool success,) = payable(msg.sender).call{value: amount}("");
        require(success, "withdrawal failed");

        emit Withdrawal(msg.sender, amount);
    }

    function submitTransaction(address to, uint256 value, bytes calldata data) external {
        require(!paused);
        require(isOwner[msg.sender]);
        uint256 id = txCount++;
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
        emit Submission(id);
    }

    function confirmTransaction(uint256 txId) external {
        require(!paused);
        require(isOwner[msg.sender]);
        Transaction storage txn = transactions[txId];
        require(!txn.executed);
        require(!confirmed[txId][msg.sender]);
        confirmed[txId][msg.sender] = true;
        txn.confirmations++;
        if (txn.confirmations == threshold) {
            txn.executionTime = block.timestamp + TIMELOCK_DURATION;
        }
        emit Confirmation(txId, msg.sender);
    }

    function executeTransaction(uint256 txId) external {
        Transaction storage txn = transactions[txId];
        require(txn.confirmations >= threshold);
        require(!txn.executed);
        // check the timelock before excuting transaction.
        require(txn.executionTime > 0, "timelock not started");
        require(block.timestamp >= txn.executionTime);
        txn.executed = true;
        (bool s,) = txn.to.call{value: txn.value}(txn.data);
        require(s);
        emit Execution(txId);
    }

    function setMerkleRoot(bytes32 root) external onlyOwner {
        merkleRoot = root;
        emit MerkleRootSet(root);
    }

    function claim(bytes32[] calldata proof, uint256 amount) external {
        require(!paused);
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, amount));
        bytes32 computed = MerkleProof.processProof(proof, leaf);
        require(computed == merkleRoot);
        require(!claimed[msg.sender]);
        claimed[msg.sender] = true;
        // change from transfer to call to avoid gas limit issues also.
        (bool success,) = payable(msg.sender).call{value: amount}("");
        require(success, "withdrawal failed");
        totalVaultValue -= amount;
        emit Claim(msg.sender, amount);
    }

    function verifySignature(address signer, bytes32 messageHash, bytes memory signature) external pure returns (bool) {
        return MerkleProof.recover(messageHash, signature) == signer;
    }

    // any one can withdraw the asset hence this need an access control
    // Hence I will need to add not just an onlyOwner modifier but onlyOwners since it's multisig.

    uint256 emergencyConfirmations;
    mapping(address => bool) public emergencyVotes;

    function emergencyWithdrawAll() external onlyOwner {
        require(!paused, "paused");
        require(!emergencyVotes[msg.sender], "already voted");
        emergencyVotes[msg.sender] = true;
        emergencyConfirmations++;
        if (emergencyConfirmations >= threshold) {
            uint256 amount = address(this).balance;
            totalVaultValue = 0;
            (bool success,) = payable(safeAddress).call{value: amount}("");
            require(success, "transfer failed");
        }
    }

    mapping(address => bool) hasPaused;
    mapping(address => bool) hasUnPaused;
    uint256 public pauseVotes;
    uint256 public unPausedVotes;

    function pause() external {
        require(isOwner[msg.sender]);
        require(!hasPaused[msg.sender], "already voted");
        hasPaused[msg.sender] = true;
        pauseVotes++;
        if (pauseVotes >= threshold) {
            paused = true;
        }
    }

    function unpause() external {
        require(isOwner[msg.sender]);
        require(!hasUnPaused[msg.sender], "already voted");
        hasUnPaused[msg.sender] = true;
        unPausedVotes++;
        if (unPausedVotes >= threshold) {
            paused = false;
        }
    }
}

