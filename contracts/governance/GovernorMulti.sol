// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (governance/Governor.sol)

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/structs/DoubleEndedQueue.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Timers.sol";
import "./IGovernorMulti.sol";

/**
 * @dev Core of the governance system, designed to be extended though various modules.
 *
 * This contract is abstract and requires several function to be implemented in various modules:
 *
 * - A counting module must implement {quorum}, {_quorumReached}, {_voteSucceeded} and {_countVote}
 * - A voting module must implement {_getVotes}
 * - Additionally, the {votingPeriod} must also be implemented
 *
 * _Available since v4.3._
 */
abstract contract GovernorMulti is Context, ERC165, EIP712, IGovernorMulti, IERC721Receiver, IERC1155Receiver {
    using DoubleEndedQueue for DoubleEndedQueue.Bytes32Deque;
    using SafeCast for uint256;
    using Timers for Timers.BlockNumber;

    bytes32 public constant BALLOT_TYPEHASH_MULTI = keccak256("Ballot(uint256 proposalId,uint8 support)");
    bytes32 public constant EXTENDED_BALLOT_TYPEHASH_MULTI =
        keccak256("ExtendedBallot(uint256 proposalId,uint8 support,string reason,bytes params)");

    struct ProposalCoreMulti {
        Timers.BlockNumber voteStart;
        Timers.BlockNumber voteEnd;
        bool executed;
        bool canceled;
    }

    string private _name;

    mapping(uint256 => mapping(uint256=>ProposalCoreMulti)) private _proposals;

    // This queue keeps track of the governor operating on itself. Calls to functions protected by the
    // {onlyGovernance} modifier needs to be whitelisted in this queue. Whitelisting is set in {_beforeExecute},
    // consumed by the {onlyGovernance} modifier and eventually reset in {_afterExecute}. This ensures that the
    // execution of {onlyGovernance} protected calls can only be achieved through successful proposals.
    DoubleEndedQueue.Bytes32Deque private _governanceCall;

    /**
     * @dev Restricts a function so it can only be executed through governance proposals. For example, governance
     * parameter setters in {GovernorSettings} are protected using this modifier.
     *
     * The governance executing address may be different from the Governor's own address, for example it could be a
     * valve. This can be customized by modules by overriding {_executor}. The executor is only able to invoke these
     * functions during the execution of the governor's {execute} function, and not under any other circumstances. Thus,
     * for example, additional valve proposers are not able to change governance parameters without going through the
     * governance protocol (since v4.6).
     */
    modifier onlyGovernance() {
        require(_msgSender() == _executor(), "Governor: onlyGovernance");
        if (_executor() != address(this)) {
            bytes32 msgDataHash = keccak256(_msgData());
            // loop until popping the expected operation - throw if deque is empty (operation not authorized)
            while (_governanceCall.popFront() != msgDataHash) {}
        }
        _;
    }

    /**
     * @dev Sets the value for {name} and {version}
     */
    constructor(string memory name_) EIP712(name_, version()) {
        _name = name_;
    }

    /**
     * @dev Function to receive ETH that will be handled by the governor 
     * (disabled if executor is a third party contract)
     */
    receive() external payable virtual {
        require(_executor() == address(this));
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165) returns (bool) {
        // In addition to the current interfaceId, also support previous version of the interfaceId that did not
        // include the castVoteWithReasonAndParams() function as standard
        return
            interfaceId ==
            (type(IGovernorMulti).interfaceId ^
                this.castVoteWithReasonAndParams.selector ^
                this.castVoteWithReasonAndParamsBySig.selector ^
                this.getVotesWithParams.selector) ||
            interfaceId == type(IGovernorMulti).interfaceId ||
            interfaceId == type(IERC1155Receiver).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IGovernorMulti-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IGovernorMulti-version}.
     */
    function version() public view virtual override returns (string memory) {
        return "1";
    }

    /**
     * @dev See {IGovernorMulti-hashProposal}.
     *
     * The proposal id is produced by hashing the ABI encoded `targets` array, the `values` array, the `calldatas` array
     * and the descriptionHash (bytes32 which itself is the keccak256 hash of the description string). This proposal id
     * can be produced from the proposal data which is part of the {ProposalCreated} event. It can even be computed in
     * advance, before the proposal is submitted.
     *
     * Note that the chainId and the governor address are not part of the proposal id computation. Consequently, the
     * same proposal (with same operation and same description) will have the same id if submitted on multiple governors
     * across multiple networks. This also means that in order to execute the same operation twice (on the same
     * governor) the proposer will have to change the description in order to avoid proposal id conflicts.
     */
    function hashProposal(
        // uint256 valveId,
        uint256 ,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public pure virtual override returns (uint256) {
        return uint256(keccak256(abi.encode(targets, values, calldatas, descriptionHash)));
    }

    /**
     * @dev See {IGovernorMulti-state}.
     */
    function state(uint256 valveId,uint256 proposalId) public view virtual override returns (ProposalStateMulti) {
        ProposalCoreMulti storage proposal = _proposals[valveId][proposalId];

        if (proposal.executed) {
            return ProposalStateMulti.Executed;
        }

        if (proposal.canceled) {
            return ProposalStateMulti.Canceled;
        }

        uint256 snapshot = proposalSnapshot(valveId,proposalId);

        if (snapshot == 0) {
            revert("Governor: unknown proposal id");
        }

        if (snapshot >= block.number) {
            return ProposalStateMulti.Pending;
        }

        uint256 deadline = proposalDeadline(valveId,proposalId);

        if (deadline >= block.number) {
            return ProposalStateMulti.Active;
        }

        if (_quorumReached(valveId,proposalId) && _voteSucceeded(valveId,proposalId)) {
            return ProposalStateMulti.Succeeded;
        } else {
            return ProposalStateMulti.Defeated;
        }
    }

    /**
     * @dev See {IGovernorMulti-proposalSnapshot}.
     */
    function proposalSnapshot(uint256 valveId,uint256 proposalId) public view virtual override returns (uint256) {
        return _proposals[valveId][proposalId].voteStart.getDeadline();
    }

    /**
     * @dev See {IGovernorMulti-proposalDeadline}.
     */
    function proposalDeadline(uint256 valveId,uint256 proposalId) public view virtual override returns (uint256) {
        return _proposals[valveId][proposalId].voteEnd.getDeadline();
    }

    /**
     * @dev Part of the Governor Bravo's interface: _"The number of votes required in 
     * order for a voter to become a proposer"_.
     */
    function proposalThreshold(uint256) public view virtual returns (uint256) {
        return 0;
    }

    /**
     * @dev Amount of votes already cast passes the threshold limit.
     */
    function _quorumReached(uint256 valveId,uint256 proposalId) internal view virtual returns (bool);

    /**
     * @dev Is the proposal successful or not.
     */
    function _voteSucceeded(uint256 valveId,uint256 proposalId) internal view virtual returns (bool);

    /**
     * @dev Get the voting weight of `account` at a specific `blockNumber`, for a vote as described by `params`.
     */
    function _getVotes(
        address account,
        uint256 valveId,
        uint256 blockNumber,
        bytes memory params
    ) internal view virtual returns (uint256);

    /**
     * @dev Register a vote for `proposalId` by `account` with a given `support`, voting `weight` and voting `params`.
     *
     * Note: Support is generic and can represent various things depending on the voting system used.
     */
    function _countVote(
        uint256 valveId,
        uint256 proposalId,
        address account,
        uint8 support,
        uint256 weight,
        bytes memory params
    ) internal virtual;

    /**
     * @dev Default additional encoded parameters used by castVote methods that don't include them
     *
     * Note: Should be overridden by specific implementations to use an appropriate value, the
     * meaning of the additional params, in the context of that implementation
     */
    function _defaultParams() internal view virtual returns (bytes memory) {
        return "";
    }

    /**
     * @dev See {IGovernorMulti-propose}.
     */
    function propose(
        uint256 valveId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public override virtual returns (uint256) {
        require(
            getVotes(_msgSender(), valveId, block.number - 1) >= proposalThreshold(valveId),
            "GovernorMulti: proposer votes below proposal threshold"
        );

        uint256 proposalId = hashProposal(valveId,targets, values, calldatas, keccak256(bytes(description)));

        require(targets.length == values.length, "GovernorMulti: invalid proposal length");
        require(targets.length == calldatas.length, "GovernorMulti: invalid proposal length");
        require(targets.length > 0, "GovernorMulti: empty proposal");

        ProposalCoreMulti storage proposal = _proposals[valveId][proposalId];
        require(proposal.voteStart.isUnset(), "GovernorMulti: proposal already exists");

        uint64 snapshot = block.number.toUint64() + votingDelay(valveId).toUint64();
        uint64 deadline = snapshot + votingPeriod(valveId).toUint64();

        proposal.voteStart.setDeadline(snapshot);
        proposal.voteEnd.setDeadline(deadline);

        emit ProposalCreated(
            valveId,
            proposalId,
            _msgSender(),
            targets,
            values,
            new string[](targets.length),
            calldatas,
            snapshot,
            deadline,
            description
        );

        return proposalId;
    }

    /**
     * @dev See {IGovernorMulti-execute}.
     */
    function execute(
        uint256 valveId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public payable virtual override returns (uint256) {
        uint256 proposalId = hashProposal(valveId,targets, values, calldatas, descriptionHash);

        ProposalStateMulti status = state(valveId,proposalId);
        require(
            status == ProposalStateMulti.Succeeded || status == ProposalStateMulti.Queued,
            "GovernorMulti: proposal not successful"
        );
        _proposals[valveId][proposalId].executed = true;

        emit ProposalExecuted(valveId,proposalId);

        _beforeExecute(valveId,proposalId, targets, values, calldatas, descriptionHash);
        _execute(valveId,proposalId, targets, values, calldatas, descriptionHash);
        _afterExecute(valveId,proposalId, targets, values, calldatas, descriptionHash);

        return proposalId;
    }

    /**
     * @dev Internal execution mechanism. Can be overridden to implement different execution mechanism
     */
    function _execute(
        uint256,
        uint256, /* proposalId */
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 /*descriptionHash*/
    ) internal virtual {
        string memory errorMessage = "GovernorMulti: call reverted without message";
        for (uint256 i = 0; i < targets.length;) {
            (bool success, bytes memory returndata) = targets[i].call{value: values[i]}(calldatas[i]);
            Address.verifyCallResult(success, returndata, errorMessage);
            unchecked{++i;}
        }
    }

    /**
     * @dev Hook before execution is triggered.
     */
    function _beforeExecute(
        uint256,
        uint256, /* proposalId */
        address[] memory targets,
        uint256[] memory, /* values */
        bytes[] memory calldatas,
        bytes32 /*descriptionHash*/
    ) internal virtual {
        if (_executor() != address(this)) {
            for (uint256 i = 0; i < targets.length;) {
                if (targets[i] == address(this)) {
                    _governanceCall.pushBack(keccak256(calldatas[i]));
                }
                unchecked{++i;}
            }
        }
    }

    /**
     * @dev Hook after execution is triggered.
     */
    function _afterExecute(
        uint256,
        uint256, /* proposalId */
        address[] memory, /* targets */
        uint256[] memory, /* values */
        bytes[] memory, /* calldatas */
        bytes32 /*descriptionHash*/
    ) internal virtual {
        if (_executor() != address(this)) {
            if (!_governanceCall.empty()) {
                _governanceCall.clear();
            }
        }
    }

    /**
     * @dev Internal cancel mechanism: locks up the proposal timer, preventing it from being re-submitted. Marks it as
     * canceled to allow distinguishing it from executed proposals.
     *
     * Emits a {IGovernorMulti-ProposalCanceled} event.
     */
    function _cancel(
        uint256 valveId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal virtual returns (uint256) {
        uint256 proposalId = hashProposal(valveId,targets, values, calldatas, descriptionHash);
        ProposalStateMulti status = state(valveId,proposalId);

        require(
            status != ProposalStateMulti.Canceled && 
            status != ProposalStateMulti.Expired && 
            status != ProposalStateMulti.Executed,
            "Governor: proposal not active"
        );
        _proposals[valveId][proposalId].canceled = true;

        emit ProposalCanceled(valveId,proposalId);

        return proposalId;
    }

    /**
     * @dev See {IGovernorMulti-getVotes}.
     */
    function getVotes(
        address account, 
        uint256 valveId, 
        uint256 blockNumber
    ) public view virtual override returns (uint256) {
        return _getVotes(account, valveId, blockNumber, _defaultParams());
    }

    /**
     * @dev See {IGovernorMulti-getVotesWithParams}.
     */
    function getVotesWithParams(
        address account,
        uint256 valveId,
        uint256 blockNumber,
        bytes memory params
    ) public view virtual override returns (uint256) {
        return _getVotes(account, valveId,blockNumber, params);
    }

    /**
     * @dev See {IGovernorMulti-castVote}.
     */
    function castVote(uint256 valveId,uint256 proposalId, uint8 support) public virtual override returns (uint256) {
        address voter = _msgSender();
        return _castVote(valveId,proposalId, voter, support, "");
    }

    /**
     * @dev See {IGovernorMulti-castVoteWithReason}.
     */
    function castVoteWithReason(
        uint256 valveId,
        uint256 proposalId,
        uint8 support,
        string calldata reason
    ) public virtual override returns (uint256) {
        address voter = _msgSender();
        return _castVote(valveId,proposalId, voter, support, reason);
    }

    /**
     * @dev See {IGovernorMulti-castVoteWithReasonAndParams}.
     */
    function castVoteWithReasonAndParams(
        uint256 valveId,
        uint256 proposalId,
        uint8 support,
        string calldata reason,
        bytes memory params
    ) public virtual override returns (uint256) {
        address voter = _msgSender();
        return _castVote(valveId,proposalId, voter, support, reason, params);
    }

    /**
     * @dev See {IGovernorMulti-castVoteBySig}.
     */
    function castVoteBySig(
        uint256 valveId,
        uint256 proposalId,
        uint8 support,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual override returns (uint256) {
        address voter = ECDSA.recover(
            _hashTypedDataV4(keccak256(abi.encode(BALLOT_TYPEHASH_MULTI, valveId,proposalId,support))),
            v,
            r,
            s
        );
        return _castVote(valveId,proposalId, voter, support, "");
    }

    /**
     * @dev See {IGovernorMulti-castVoteWithReasonAndParamsBySig}.
     */
    function castVoteWithReasonAndParamsBySig(
        uint256 valveId,
        uint256 proposalId,
        uint8 support,
        string calldata reason,
        bytes memory params,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual override returns (uint256) {
        address voter = ECDSA.recover(
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        EXTENDED_BALLOT_TYPEHASH_MULTI,
                        valveId,
                        proposalId,
                        support,
                        keccak256(bytes(reason)),
                        keccak256(params)
                    )
                )
            ),
            v,
            r,
            s
        );

        return _castVote(valveId,proposalId, voter, support, reason, params);
    }

    /**
     * @dev Internal vote casting mechanism: Check that the vote is pending, that it has not been cast yet, 
     * retrieve voting weight using {IGovernorMulti-getVotes} and 
     * call the {_countVote} internal function. Uses the _defaultParams().
     *
     * Emits a {IGovernorMulti-VoteCast} event.
     */
    function _castVote(
        uint256 valveId,
        uint256 proposalId,
        address account,
        uint8 support,
        string memory reason
    ) internal virtual returns (uint256) {
        return _castVote(valveId,proposalId, account, support, reason, _defaultParams());
    }

    /**
     * @dev Internal vote casting mechanism: Check that the vote is pending, that it has not been cast yet, retrieve
     * voting weight using {IGovernorMulti-getVotes} and call the {_countVote} internal function.
     *
     * Emits a {IGovernorMulti-VoteCast} event.
     */
    function _castVote(
        uint256 valveId,
        uint256 proposalId,
        address account,
        uint8 support,
        string memory reason,
        bytes memory params
    ) internal virtual returns (uint256) {
        ProposalCoreMulti storage proposal = _proposals[valveId][proposalId];
        require(state(valveId,proposalId) == ProposalStateMulti.Active, "Governor: vote not currently active");

        uint256 weight = _getVotes(account, valveId, proposal.voteStart.getDeadline(), params);
        _countVote(valveId, proposalId, account, support, weight, params);

        if (params.length == 0) {
            emit VoteCast(account,valveId, proposalId, support, weight, reason);
        } else {
            emit VoteCastWithParams(account, valveId, proposalId, support, weight, reason, params);
        }

        return weight;
    }

    /**
     * @dev Relays a transaction or function call to an arbitrary target. In cases where the governance executor
     * is some contract other than the governor itself, like when using a valve, this function can be invoked
     * in a governance proposal to recover tokens or Ether that was sent to the governor contract by mistake.
     * Note that if the executor is simply the governor itself, use of `relay` is redundant.
     */
    function relay(
        address target,
        uint256 value,
        bytes calldata data
    ) external payable virtual onlyGovernance {
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        Address.verifyCallResult(success, returndata, "Governor: relay reverted without message");
    }

    /**
     * @dev Address through which the governor executes action. Will be overloaded by module that execute actions
     * through another contract such as a valve.
     */
    function _executor() internal view virtual returns (address) {
        return address(this);
    }

    /**
     * @dev See {IERC721Receiver-onERC721Received}.
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /**
     * @dev See {IERC1155Receiver-onERC1155Received}.
     */
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    /**
     * @dev See {IERC1155Receiver-onERC1155BatchReceived}.
     */
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}
