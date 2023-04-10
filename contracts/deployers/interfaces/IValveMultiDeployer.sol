// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IValveMultiDeployer {
    function createValveMulti(
        uint256 minDelay, 
        address[] calldata proposers,
        address[] calldata executors) 
    external;

    function getValveMulti() external view returns (address);
    function setUpContract(address governorContractMulti) external;
}