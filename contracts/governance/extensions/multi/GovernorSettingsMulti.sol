// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (governance/extensions/GovernorSettings.sol)

pragma solidity ^0.8.0;

import "../../GovernorMulti.sol";

/**
 * @dev Extension of {Governor} for settings updatable through governance.
 *
 * _Available since v4.4._
 */
abstract contract GovernorSettingsMulti is GovernorMulti {
    mapping (uint256 => uint256) private _votingDelay;
    mapping (uint256 => uint256) private _votingPeriod;
    mapping (uint256 => uint256) private _proposalThreshold;

    event VotingDelaySet(uint256 oldVotingDelay, uint256 newVotingDelay);
    event VotingPeriodSet(uint256 oldVotingPeriod, uint256 newVotingPeriod);
    event ProposalThresholdSet(uint256 oldProposalThreshold, uint256 newProposalThreshold);

    /**
     * @dev Initialize the governance parameters.
     */
    constructor(
        uint256 initialProposalThreshold
    ) {
        _setProposalThreshold(0, initialProposalThreshold);
    }

    /**
     * @dev See {IGovernor-votingDelay}.
     */
    function votingDelay(uint256 index) public view virtual override returns (uint256) {
        return _votingDelay[index];
    }

    /**
     * @dev See {IGovernor-votingPeriod}.
     */
    function votingPeriod(uint256 index) public view virtual override returns (uint256) {
        return _votingPeriod[index];
    }

    /**
     * @dev See {Governor-proposalThreshold}.
     */
    function proposalThreshold(uint256 index) public view virtual override returns (uint256) {
        return _proposalThreshold[index];
    }

    /**
     * @dev Update the voting delay. This operation can only be performed through a governance proposal.
     *
     * Emits a {VotingDelaySet} event.
     */
    function setVotingDelay(uint256 index, uint256 newVotingDelay) public virtual onlyGovernance {
        _setVotingDelay(index, newVotingDelay);
    }

    /**
     * @dev Update the voting period. This operation can only be performed through a governance proposal.
     *
     * Emits a {VotingPeriodSet} event.
     */
    function setVotingPeriod(uint256 index, uint256 newVotingPeriod) public virtual onlyGovernance {
        _setVotingPeriod(index, newVotingPeriod);
    }

    /**
     * @dev Update the proposal threshold. This operation can only be performed through a governance proposal.
     *
     * Emits a {ProposalThresholdSet} event.
     */
    function setProposalThreshold(uint256 index, uint256 newProposalThreshold) public virtual onlyGovernance {
        _setProposalThreshold(index,newProposalThreshold);
    }

    /**
     * @dev Internal setter for the voting delay.
     *
     * Emits a {VotingDelaySet} event.
     */
    function _setVotingDelay(uint256 index, uint256 newVotingDelay) internal virtual {
        emit VotingDelaySet(_votingDelay[index], newVotingDelay);
        _votingDelay[index] = newVotingDelay;
    }

    /**
     * @dev Internal setter for the voting period.
     *
     * Emits a {VotingPeriodSet} event.
     */
    function _setVotingPeriod(uint256 index,uint256 newVotingPeriod) internal virtual {
        // voting period must be at least one block long
        require(newVotingPeriod > 0, "GovernorSettings: voting period too low");
        emit VotingPeriodSet(_votingPeriod[index], newVotingPeriod);
        _votingPeriod[index] = newVotingPeriod;
    }

    /**
     * @dev Internal setter for the proposal threshold.
     *
     * Emits a {ProposalThresholdSet} event.
     */
    function _setProposalThreshold(uint256 index, uint256 newProposalThreshold) internal virtual {
        emit ProposalThresholdSet(_proposalThreshold[index], newProposalThreshold);
        _proposalThreshold[index] = newProposalThreshold;
    }
}
