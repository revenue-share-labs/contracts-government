// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./governance/ValveControllerMulti.sol";

contract ValveMulti is ValveControllerMulti {
  bytes32 public constant VALVE_ADMIN_ROLE = keccak256("VALVE_ADMIN_ROLE");

  // minDelay is how long you have to wait before executing
  // proposers is the list of addresses that can propose
  // executors is the list of addresses that can execute
  constructor(
    uint256 minDelay,
    address[] memory proposers,
    address[] memory executors,
    address admin
  ) ValveControllerMulti(minDelay, proposers, executors, admin) {}
}
