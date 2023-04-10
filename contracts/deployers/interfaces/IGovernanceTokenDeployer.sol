// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGovernanceTokenDeployer {
    function createGovernanceTokenMulti() external;
    function getGovernanceToken() external view returns (address);
}