// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (governance/extensions/GovernorValveControl.sol)

pragma solidity ^0.8.0;

import "./IGovernorValveMulti.sol";
import "../../GovernorMulti.sol";
import "../../ValveControllerMulti.sol";

/**
 * @dev Extension of {Governor} that binds the execution process to an instance of {ValveController}. This adds a
 * delay, enforced by the {ValveController} to all successful proposal (in addition to the voting duration). The
 * {Governor} needs the proposer (and ideally the executor) roles for the {Governor} to work properly.
 *
 * Using this model means the proposal will be operated by the {ValveController} and not by the {Governor}. Thus,
 * the assets and permissions must be attached to the {ValveController}. Any asset sent to the {Governor} will be
 * inaccessible.
 *
 * WARNING: Setting up the ValveController to have additional proposers besides the governor is very risky, as it
 * grants them powers that they must be trusted or known not to use: 1) {onlyGovernance} functions like {relay} are
 * available to them through the timelock, and 2) approved governance proposals can be blocked by them, effectively
 * executing a Denial of Service attack. This risk will be mitigated in a future release.
 *
 * _Available since v4.3._
 */
abstract contract GovernorValveControlMulti is
    IGovernorValveMulti,
    GovernorMulti
{
    ValveControllerMulti private _valve;
    mapping(uint256 => mapping(uint256 => bytes32)) public _valveIds;

    /**
     * @dev Emitted when the valve controller used for proposal execution is modified.
     */
    event ValveChange(address oldValve, address newValve);

    /**
     * @dev Set the valve.
     */
    constructor(ValveControllerMulti valveAddress) {
        _updateValve(valveAddress);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(IERC165, GovernorMulti) returns (bool) {
        return
            interfaceId == type(IGovernorValveMulti).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev Overridden version of the {Governor-state} function with added support for the `Queued` status.
     */
    function state(
        uint256 valveId,
        uint256 proposalId
    )
        public
        view
        virtual
        override(IGovernorMulti, GovernorMulti)
        returns (ProposalStateMulti)
    {
        ProposalStateMulti status = super.state(valveId, proposalId);

        if (status != ProposalStateMulti.Succeeded) {
            return status;
        }

        // core tracks execution, so we just have to check if successful proposal have been queued.
        bytes32 queueid = _valveIds[valveId][proposalId];
        if (queueid == bytes32(0)) {
            return status;
        } else if (
            ValveController(_valve.getValve(valveId))
                .isOperationDone(queueid)
        ) {
            return ProposalStateMulti.Executed;
        } else if (
            ValveController(_valve.getValve(valveId))
                .isOperationPending(queueid)
        ) {
            return ProposalStateMulti.Queued;
        } else {
            return ProposalStateMulti.Canceled;
        }
    }

    /**
     * @dev Public accessor to check the address of the valve
     */
    function valve(
        uint256 valveId
    ) public view virtual override returns (address) {
        return address(_valve.getValve(valveId));
    }

    /**
     * @dev Public accessor to check the eta of a queued proposal
     */
    function proposalEta(
        uint256 valveId,
        uint256 proposalId
    ) public view virtual override returns (uint256) {
        uint256 eta = ValveController(_valve.getValve(valveId))
            .getTimestamp(_valveIds[valveId][proposalId]);
        return eta == 1 ? 0 : eta; // _DONE_TIMESTAMP (1) should be replaced with a 0 value
    }

    /**
     * @dev Function to queue a proposal to the valve.
     */
    function queue(
        uint256 valveId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public virtual override returns (uint256) {
        // uint256 proposalId = hashProposal(valveId, targets, values, calldatas, descriptionHash);
        uint256 proposalId = hashProposal(
            valveId,
            targets,
            values,
            calldatas,
            descriptionHash
        );

        require(
            state(valveId, proposalId) == ProposalStateMulti.Succeeded,
            "Governor: proposal not successful"
        );

        uint256 delay = ValveController(_valve.getValve(valveId))
            .getMinDelay();
        _valveIds[valveId][proposalId] = ValveController(
            _valve.getValve(valveId)
        ).hashOperationBatch(targets, values, calldatas, 0, descriptionHash);
        
        ValveController(_valve.getValve(valveId)).scheduleBatch(
            targets,
            values,
            calldatas,
            0,
            descriptionHash,
            delay
        );

        emit ProposalQueued(valveId, proposalId, block.timestamp + delay);

        return proposalId;
    }

    /**
     * @dev Overridden execute function that run the already queued proposal through the valve.
     */
    function _execute(
        uint256 valveId,
        uint256 /* proposalId */,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal virtual override {
        ValveController(_valve.getValve(valveId)).executeBatch{
            value: msg.value
        }(targets, values, calldatas, 0, descriptionHash);
    }

    /**
     * @dev Overridden version of the {Governor-_cancel} function to cancel the timelocked proposal if it as already
     * been queued.
     */
    // This function can reenter through the external call to the valve, but we assume the valve is trusted and
    // well behaved (according to ValveController) and this will not happen.
    // slither-disable-next-line reentrancy-no-eth
    function _cancel(
        uint256 valveId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal virtual override returns (uint256) {
        uint256 proposalId = super._cancel(
            valveId,
            targets,
            values,
            calldatas,
            descriptionHash
        );

        if (_valveIds[valveId][proposalId] != 0) {
            ValveController(_valve.getValve(valveId)).cancel(
                _valveIds[valveId][proposalId]
            );
            delete _valveIds[valveId][proposalId];
        }

        return proposalId;
    }

    /**
     * @dev Address through which the governor executes action. In this case, the valve.
     */
    function _executor(
        uint256 valveId
    ) internal view virtual returns (address) {
        return _valve.getValve(valveId);
    }

    /**
     * @dev Public endpoint to update the underlying valve instance. Restricted to the valve itself, so updates
     * must be proposed, scheduled, and executed through governance proposals.
     *
     * CAUTION: It is not recommended to change the valve while there are other queued governance proposals.
     */
    function updateValve(
        ValveControllerMulti newValve
    ) external virtual onlyGovernance {
        _updateValve(newValve);
    }

    function _updateValve(ValveControllerMulti newValve) private {
        emit ValveChange(address(_valve), address(newValve));
        _valve = newValve;
    }
}
