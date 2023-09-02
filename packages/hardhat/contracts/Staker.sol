// SPDX-License-Identifier: MIT
pragma solidity 0.8.4; // Do not change the Solidity version as it negatively impacts submission grading

/// @title Staker Dapp
/// @author Bartłomiej Lemieszek
/// @notice Allows for safe ETH staking on an external contract with a certain deadline and threshold.
/// @dev All implemented functions are working correctly.

import "hardhat/console.sol";
import "./ExampleExternalContract.sol";

contract Staker {
    event Stake(address indexed sender, uint256 value);

    mapping(address => uint256) public balances;
    uint256 public constant THRESHOLD = 1 ether;
    uint256 public deadline;
    ExampleExternalContract public exampleExternalContract;
    bool openForWithdraw = false;

    /// @param exampleExternalContractAddress The address of the external contract for staking.
    constructor(address exampleExternalContractAddress) {
        exampleExternalContract = ExampleExternalContract(
            exampleExternalContractAddress
        );
        deadline = block.timestamp + 72 hours;
    }

    /// @notice Ensure that the staking is not already completed.
    modifier completed() {
        bool completedStatus = exampleExternalContract.completed();
        require(!completedStatus, "Staking already completed");
        _;
    }

    /// @notice Ensure that the deadline has not passed yet.
    /// @param requireDeadlinePassed A flag to specify whether the deadline should be passed or not.
    /// @dev Modifier used for functions that might need the deadline to be passed.
    modifier deadlinePassed(bool requireDeadlinePassed) {
        uint256 timeRemaining = timeLeft();
        if (requireDeadlinePassed) {
            require(timeRemaining <= 0, "Deadline not passed yet");
        } else {
            require(timeRemaining > 0, "Deadline has already passed");
        }
        _;
    }

    /// @notice Track sender's balance after they stake ETH.
    /// @dev Emits an event for the frontend.
    function stake() external payable deadlinePassed(false) completed {
        balances[msg.sender] += msg.value;
        emit Stake(msg.sender, msg.value);
    }

    /// @notice Manually check if the threshold was met (if staking is complete).
    /// If met, enable withdrawal; otherwise, open for withdrawal.
    function execute() public completed {
        uint256 contractBalance = address(this).balance;

        if (contractBalance > THRESHOLD) {
            exampleExternalContract.complete{value: address(this).balance}();
        } else {
            openForWithdraw = true;
        }
    }

    /// @notice Allows withdrawing funds if the threshold was not met.
    function withdraw() public deadlinePassed(true) completed {
        require(address(this).balance < THRESHOLD, "Threshold met");
        require(openForWithdraw, "Not open for withdrawal");
        uint256 userBalance = balances[msg.sender];
        require(userBalance > 0, "User balance is 0");
        balances[msg.sender] = 0;
        (bool sent, ) = payable(msg.sender).call{value: userBalance}("");
        require(sent, "Failed to send Ether");
    }

    /// @notice Get the time left until the deadline.
    /// @return The remaining time in seconds.
    function timeLeft() public view returns (uint256) {
        if (block.timestamp >= deadline) {
            return 0;
        } else {
            return deadline - block.timestamp;
        }
    }

    /// @dev Fallback function to allow receiving Ether directly and stake.
    receive() external payable {
        this.stake();
    }
}
