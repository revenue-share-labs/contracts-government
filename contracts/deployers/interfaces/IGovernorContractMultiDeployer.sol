// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGovernorContractMultiDeployer {
    function createGovernorContractMulti(
        address governanceToken,
        address payable valveMulti
    ) external;

    function getGovernorContractMulti() external view returns (address);
}