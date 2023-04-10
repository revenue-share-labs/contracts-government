// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (governance/extensions/GovernorVotesQuorumFraction.sol)

pragma solidity ^0.8.0;

import "./GovernorVotesMulti.sol";
import "@openzeppelin/contracts/utils/Checkpoints.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

/**
 * @dev Extension of {Governor} for voting weight extraction from an {ERC20Votes} token and a quorum expressed as a
 * fraction of the total supply.
 *
 * _Available since v4.3._
 */
abstract contract GovernorVotesQuorumFractionMulti is GovernorVotesMulti {
    using Checkpoints for Checkpoints.History;

    mapping (uint256=> uint256) private _quorumNumerator; // DEPRECATED
    mapping (uint256=> Checkpoints.History) private _quorumNumeratorHistory;

    event QuorumNumeratorUpdated(uint256 valveId, uint256 oldQuorumNumerator, uint256 newQuorumNumerator);

    /**
     * @dev Initialize quorum as a fraction of the token's total supply.
     *
     * The fraction is specified as `numerator / denominator`. By default the denominator is 100, so quorum is
     * specified as a percent: a numerator of 10 corresponds to quorum being 10% of total supply. The denominator can be
     * customized by overriding {quorumDenominator}.
     */
    // constructor(uint256 valveId, uint256 quorumNumeratorValue) {
    constructor() {
        // _updateQuorumNumerator(valveId, quorumNumeratorValue);
    }

    /**
     * @dev Returns the current quorum numerator. See {quorumDenominator}.
     */
    function quorumNumerator(uint256 valveId) public view virtual returns (uint256) {
        return (_quorumNumeratorHistory[valveId]._checkpoints.length == 0 ? 
            _quorumNumerator[valveId] : 
            _quorumNumeratorHistory[valveId].latest()
        );
    }

    /**
     * @dev Returns the quorum numerator at a specific block number. See {quorumDenominator}.
     */
    function quorumNumerator(uint256 valveId,uint256 blockNumber) public view virtual returns (uint256) {
        // If history is empty, fallback to old storage
        uint256 length = _quorumNumeratorHistory[valveId]._checkpoints.length;
        if (length == 0) {
            return _quorumNumerator[valveId];
        }

        // Optimistic search, check the latest checkpoint
        Checkpoints.Checkpoint memory latest = _quorumNumeratorHistory[valveId]._checkpoints[length - 1];
        if (latest._blockNumber <= blockNumber) {
            return latest._value;
        }

        // Otherwise, do the binary search
        return _quorumNumeratorHistory[valveId].getAtBlock(blockNumber);
    }

    /**
     * @dev Returns the quorum denominator. Defaults to 100, but may be overridden.
     */
    function quorumDenominator() public view virtual returns (uint256) {
        return 100;
    }

    /**
     * @dev Returns the quorum for a block number, in terms of number of votes: `supply * numerator / denominator`.
     */
    function quorum(uint256 valveId,uint256 blockNumber) public view virtual override returns (uint256) {
        return (
            (token.getPastTotalSupply(valveId, blockNumber) * 
            quorumNumerator(valveId, blockNumber)) / 
            quorumDenominator()
        );
    }

    /**
     * @dev Changes the quorum numerator.
     *
     * Emits a {QuorumNumeratorUpdated} event.
     *
     * Requirements:
     *
     * - Must be called through a governance proposal.
     * - New numerator must be smaller or equal to the denominator.
     */
    function updateQuorumNumerator(uint256 valveId, uint256 newQuorumNumerator) external virtual onlyGovernance {
        _updateQuorumNumerator(valveId, newQuorumNumerator);
    }

    /**
     * @dev Changes the quorum numerator.
     *
     * Emits a {QuorumNumeratorUpdated} event.
     *
     * Requirements:
     *
     * - New numerator must be smaller or equal to the denominator.
     */
    function _updateQuorumNumerator(uint256 valveId, uint256 newQuorumNumerator) internal virtual {
        require(
            newQuorumNumerator <= quorumDenominator(),
            "GovernorVotesQuorumFraction: quorumNumerator over quorumDenominator"
        );

        uint256 oldQuorumNumerator = quorumNumerator(valveId);

        // Make sure we keep track of the original numerator in contracts upgraded from a version without checkpoints.
        if (oldQuorumNumerator != 0 && _quorumNumeratorHistory[valveId]._checkpoints.length == 0) {
            _quorumNumeratorHistory[valveId]._checkpoints.push(
                Checkpoints.Checkpoint({_blockNumber: 0, _value: SafeCast.toUint224(oldQuorumNumerator)})
            );
        }

        // Set new quorum for future proposals
        _quorumNumeratorHistory[valveId].push(newQuorumNumerator);

        emit QuorumNumeratorUpdated(valveId,oldQuorumNumerator, newQuorumNumerator);
    }
}
