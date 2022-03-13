pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: MIT

import 'hardhat/console.sol';
import './ExampleExternalContract.sol';

contract Staker {
  ExampleExternalContract public exampleExternalContract;

  enum Status {
    STAKING,
    SUCCESS,
    WITHDRAW
  }
  event Stake(address indexed from, uint256 indexed amount);

  Status public currStatus;

  uint256 constant threshold = 1 ether;

  mapping(address => uint256) public balances;

  uint256 public deadline = block.timestamp + 60 seconds;

  constructor(address exampleExternalContractAddress) {
    exampleExternalContract = ExampleExternalContract(exampleExternalContractAddress);
    currStatus = Status.STAKING;
  }

  receive() external payable {
    stake(msg.value);
  }

  function stake(uint256 amount) public payable deadlineReached(false) onlyWithStatus(Status.STAKING) {
    require(amount > 0 && amount <= threshold, 'SHOULD BE GRATHER THAN ZERO');

    balances[msg.sender] = amount;

    if (address(this).balance == threshold) {
      currStatus = Status.SUCCESS;
      this.execute();
    }

    if (timeLeft() == 0 && address(this).balance < threshold) {
      currStatus = Status.WITHDRAW;
    }

    emit Stake(msg.sender, amount);
  }

  // Collect funds in a payable `stake()` function and track individual `balances` with a mapping:
  //  ( make sure to add a `Stake(address,uint256)` event and emit it for the frontend <List/> display )

  // After some `deadline` allow anyone to call an `execute()` function
  //  It should either call `exampleExternalContract.complete{value: address(this).balance}()` to send all the value
  function execute() public onlyWithStatus(Status.SUCCESS) {
    exampleExternalContract.complete{value: address(this).balance}();
  }

  // if the `threshold` was not met, allow everyone to call a `withdraw()` function
  function withdraw() public payable onlyWithStatus(Status.WITHDRAW) {
    require(balances[msg.sender] != 0, 'NOT CONTRIBUTED');

    (bool success, ) = payable(msg.sender).call{value: balances[msg.sender]}('');

    if (success) {
      balances[msg.sender] = 0;
    }

    require(success, 'Failed to send Ether');
  }

  // Add a `timeLeft()` view function that returns the time left before the deadline for the frontend
  function timeLeft() public view returns (uint256 timeleft) {
    return block.timestamp >= deadline ? 0 : deadline - block.timestamp;
  }

  function getState() public view returns (Status) {
    return currStatus;
  }

  // Add the `receive()` special function that receives eth and calls stake()

  modifier onlyWithStatus(Status _status) {
    require(currStatus == _status, 'Incorrect status for executing function');
    _;
  }

  modifier deadlineReached(bool reached) {
    uint256 timeRemaining = timeLeft();
    require(reached ? timeRemaining > 0 : timeRemaining == 0);
    _;
  }
}
