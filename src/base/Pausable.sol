// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract Pausable {
    bool public paused;

    mapping(address => bool) internal hasPaused;
    mapping(address => bool) internal hasUnPaused;
    uint256 public pauseVotes;
    uint256 public unPausedVotes;

    function _pause(address voter, uint256 threshold) internal {
        require(!hasPaused[voter], "already voted");
        hasPaused[voter] = true;
        pauseVotes++;
        if (pauseVotes >= threshold) {
            paused = true;
        }
    }

    function _unpause(address voter, uint256 threshold) internal {
        require(!hasUnPaused[voter], "already voted");
        hasUnPaused[voter] = true;
        unPausedVotes++;
        if (unPausedVotes >= threshold) {
            paused = false;
        }
    }
}
