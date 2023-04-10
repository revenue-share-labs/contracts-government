// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../../IGovernorMulti.sol";

/**
 * @dev Extension of the {IGovernor} for valve supporting modules.
 *
 * _Available since v4.3._
 */
abstract contract IGovernorValveMulti is IGovernorMulti {
    event ProposalQueued(uint256 valveId, uint256 proposalId, uint256 eta);

    function valve(uint256 valveId) public view virtual returns (address);

    function proposalEta(uint256 valveId,uint256 proposalId) public view virtual returns (uint256);

    function queue(
        uint256 valveId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public virtual returns (uint256 proposalId);
}
