## EvictionVault — Bug Fixes & Design Decisions
### Author: Sunday Justice Gabriel

### BUG FIXES

### 1. emergencyWithdrawAll — Public Drain
Any single owner could drain the vault alone. Fixed by adding a vote
counter so the withdrawal only executes once threshold owners have
approved. Funds go to an immutable safeAddress set at deployment, not
to whoever calls the function.

### 2. pause/unpause — Single Owner Control
Either function could be triggered by one owner. Fixed with the same
voting pattern — pauseVotes and unPausedVotes counters ensure threshold
agreement is required before state changes.

### 3. setMerkleRoot — Callable by Anyone
Missing access control. Fixed by adding the onlyOwner modifier.

### 4. receive() — Used tx.origin
tx.origin always refers to the original EOA, not the direct caller.change to msg.sender.

### 5. withdraw & claim — Used .transfer()
changed to call which is cheaper

### 6. Timelock Bypass
executeTransaction checked block.timestamp >= txn.executionTime, but
executionTime defaults to 0, meaning transactions that never reached
threshold could still execute immediately. Fixed by adding
require(txn.executionTime > 0, "timelock not started").

### 7. verifySignature — Wrong Library (was showing error on my vsCode, hence the fix)
MerkleProof.recover() does not exist. MerkleProof is for verifying
merkle tree proofs. Signature recovery requires ECDSA.recover(). Fixed
by introducing a SignatureVerifier library that imports and uses ECDSA
from OpenZeppelin.

### PROJECT STRUCTURE

``` 
    src/
  EvictionVault.sol
  interfaces/IEvictionVault.sol
  base/MultiSig.sol
  base/MerkleDistributor.sol
  base/Pausable.sol
  librarirs/SignatureVerifier.sol 

  ```