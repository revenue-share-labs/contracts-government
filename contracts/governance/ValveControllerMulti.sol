// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (governance/ValveController.sol)

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "./ValveController.sol";

/**
 * @dev Contract module which acts as a timelocked controller. When set as the
 * owner of an `Ownable` smart contract, it enforces a timelock on all
 * `onlyOwner` maintenance operations. This gives time for users of the
 * controlled contract to exit before a potentially dangerous maintenance
 * operation is applied.
 *
 * By default, this contract is self administered, meaning administration tasks
 * have to go through the timelock process. The proposer (resp executor) role
 * is in charge of proposing (resp executing) operations. A common use case is
 * to position this {ValveController} as the owner of a smart contract, with
 * a multisig or a DAO as the sole proposer.
 *
 * _Available since v3.3._
 */
contract ValveControllerMulti is AccessControl, IERC721Receiver, IERC1155Receiver {
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");
    
    uint256 internal constant _DONE_TIMESTAMP = uint256(1);

    mapping (uint256=>mapping(bytes32 => uint256)) private _timestamps;
    uint256 private _minDelay;
    
    mapping (uint256 => address payable) private _valves;

    function setValve(uint256 valveId, address valveAddress) public {
        _valves[valveId] = payable(valveAddress);
    }

    function getValve(uint256 valveId) public view returns(address payable) {
        return payable(_valves[valveId]);
    }

    /**
     * @dev Emitted when a call is scheduled as part of operation `id`.
     */
    event CallScheduled(
        uint256 valveId,
        bytes32 indexed id,
        uint256 indexed index,
        address target,
        uint256 value,
        bytes data,
        bytes32 predecessor,
        uint256 delay
    );

    /**
     * @dev Emitted when a call is performed as part of operation `id`.
     */
    event CallExecuted(
        uint256 valveId,
        bytes32 indexed id, 
        uint256 indexed index, 
        address target, 
        uint256 value, 
        bytes data
    );

    /**
     * @dev Emitted when operation `id` is cancelled.
     */
    event Cancelled(uint256 valveId,bytes32 indexed id);

    /**
     * @dev Emitted when the minimum delay for future operations is modified.
     */
    event MinDelayChange(uint256 oldDuration, uint256 newDuration);

    /**
     * @dev Initializes the contract with the following parameters:
     *
     * - `minDelay`: initial minimum delay for operations
     * - `proposers`: accounts to be granted proposer and canceller roles
     * - `executors`: accounts to be granted executor role
     * - `admin`: optional account to be granted admin role; disable with zero address
     *
     * IMPORTANT: The optional admin can aid with initial configuration of roles after deployment
     * without being subject to delay, but this role should be subsequently renounced in favor of
     * administration through timelocked proposals. Previous versions of this contract would assign
     * this admin to the deployer automatically and should be renounced as well.
     */
    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin
    ) {
        // self administration
        _grantRole(DEFAULT_ADMIN_ROLE, address(this));

        // optional admin
        if (admin != address(0)) {
            _grantRole(DEFAULT_ADMIN_ROLE, admin);
        }

        // register proposers and cancellers
        for (uint256 i = 0; i < proposers.length;) {
            _setupRole(PROPOSER_ROLE, proposers[i]);
            _setupRole(CANCELLER_ROLE, proposers[i]);
            unchecked{++i;}
        }

        // register executors
        for (uint256 i = 0; i < executors.length;) {
            _setupRole(EXECUTOR_ROLE, executors[i]);
            unchecked{++i;}
        }

        _minDelay = minDelay;
        emit MinDelayChange(0, minDelay);
    }

    /**
     * @dev Modifier to make a function callable only by a certain role. In
     * addition to checking the sender's role, `address(0)` 's role is also
     * considered. Granting a role to `address(0)` is equivalent to enabling
     * this role for everyone.
     */
    modifier onlyRoleOrOpenRole(bytes32 role) {
        if (!hasRole(role, address(0))) {
            _checkRole(role, _msgSender());
        }
        _;
    }

    /**
     * @dev Contract might receive/hold ETH as part of the maintenance process.
     */
    receive() external payable {}

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, AccessControl) returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns whether an id correspond to a registered operation. This
     * includes both Pending, Ready and Done operations.
     */
    function isOperation(uint256 valveId, bytes32 id) public view virtual returns (bool registered) {
        return getTimestamp(valveId,id) > 0;
    }

    /**
     * @dev Returns whether an operation is pending or not.
     */
    function isOperationPending(uint256 valveId, bytes32 id) public view virtual returns (bool pending) {
        return getTimestamp(valveId,id) > _DONE_TIMESTAMP;
    }

    /**
     * @dev Returns whether an operation is ready or not.
     */
    function isOperationReady(uint256 valveId, bytes32 id) public view virtual returns (bool ready) {
        uint256 timestamp = getTimestamp(valveId,id);
        return timestamp > _DONE_TIMESTAMP && timestamp <= block.timestamp;
    }

    /**
     * @dev Returns whether an operation is done or not.
     */
    function isOperationDone(uint256 valveId, bytes32 id) public view virtual returns (bool done) {
        return getTimestamp(valveId,id) == _DONE_TIMESTAMP;
    }

    /**
     * @dev Returns the timestamp at which an operation becomes ready (0 for
     * unset operations, 1 for done operations).
     */
    function getTimestamp(uint256 valveId, bytes32 id) public view virtual returns (uint256 timestamp) {
        return _timestamps[valveId][id];
    }

    /**
     * @dev Returns the minimum delay for an operation to become valid.
     *
     * This value can be changed by executing an operation that calls `updateDelay`.
     */
    function getMinDelay() public view virtual returns (uint256 duration) {
        return _minDelay;
    }

    /**
     * @dev Returns the identifier of an operation containing a single
     * transaction.
     */
    function hashOperation(
        // uint256 valveId,
        uint256 ,
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) public pure virtual returns (bytes32 hash) {
        return keccak256(abi.encode(target, value, data, predecessor, salt));
        // return keccak256(abi.encode(valveId,target, value, data, predecessor, salt));
    }

    /**
     * @dev Returns the identifier of an operation containing a batch of
     * transactions.
     */
    function hashOperationBatch(
        // uint256 valveId,
        uint256,
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt
    ) public pure virtual returns (bytes32 hash) {
        return keccak256(abi.encode(targets, values, payloads, predecessor, salt));
        // return keccak256(abi.encode(valveId,targets, values, payloads, predecessor, salt));
    }

    /**
     * @dev Schedule an operation containing a single transaction.
     *
     * Emits a {CallScheduled} event.
     *
     * Requirements:
     *
     * - the caller must have the 'proposer' role.
     */
    function schedule(
        uint256 valveId,
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) public virtual onlyRole(PROPOSER_ROLE) {
        // bytes32 id = hashOperation(valveId,target, value, data, predecessor, salt);
        ValveController _valveController = ValveController(_valves[valveId]);
         _valveController.schedule(target,value,data,predecessor,salt,delay);
        // _schedule(valveId,id, delay);
        // emit CallScheduled(valveId,id, 0, target, value, data, predecessor, delay);
    }

    /**
     * @dev Schedule an operation containing a batch of transactions.
     *
     * Emits one {CallScheduled} event per transaction in the batch.
     *
     * Requirements:
     *
     * - the caller must have the 'proposer' role.
     */
    function scheduleBatch(
        uint256 valveId,
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) public virtual onlyRole(PROPOSER_ROLE) {
        require(targets.length == values.length, "ValveControllerMulti: length mismatch");
        require(targets.length == payloads.length, "ValveControllerMulti: length mismatch");

        // bytes32 id = hashOperationBatch(valveId,targets, values, payloads, predecessor, salt);
        ValveController _valveController = ValveController(_valves[valveId]);
         _valveController.scheduleBatch(targets,values,payloads,predecessor,salt,delay);
        // _schedule(valveId,id, delay);
        // for (uint256 i = 0; i < targets.length; ++i) {
        //     emit CallScheduled(valveId,id, i, targets[i], values[i], payloads[i], predecessor, delay);
        // }
    }

    /**
     * @dev Schedule an operation that is to become valid after a given delay.
     */
    function _schedule(uint256 valveId,bytes32 id, uint256 delay) private {
        require(!isOperation(valveId,id), "ValveControllerMulti: operation already scheduled");
        require(delay >= getMinDelay(), "ValveControllerMulti: insufficient delay");
        _timestamps[valveId][id] = block.timestamp + delay;
    }

    /**
     * @dev Cancel an operation.
     *
     * Requirements:
     *
     * - the caller must have the 'canceller' role.
     */
    function cancel(uint256 valveId,bytes32 id) public virtual onlyRole(CANCELLER_ROLE) {
        require(isOperationPending(valveId,id), "ValveControllerMulti: operation cannot be cancelled");
        delete _timestamps[valveId][id];

        emit Cancelled(valveId,id);
    }

    /**
     * @dev Execute an (ready) operation containing a single transaction.
     *
     * Emits a {CallExecuted} event.
     *
     * Requirements:
     *
     * - the caller must have the 'executor' role.
     */
    // This function can reenter, but it doesn't pose a risk because _afterCall checks that the proposal is pending,
    // thus any modifications to the operation during reentrancy should be caught.
    // slither-disable-next-line reentrancy-eth
    function execute(
        uint256 valveId,
        address target,
        uint256 value,
        bytes calldata payload,
        bytes32 predecessor,
        bytes32 salt
    ) public payable virtual onlyRoleOrOpenRole(EXECUTOR_ROLE) {
        bytes32 id = hashOperation(valveId,target, value, payload, predecessor, salt);

        ValveController _valveController = ValveController(_valves[valveId]);
        
        _beforeCall(valveId,id, predecessor);
        _valveController.execute(target, value, payload, predecessor, salt);
        // _execute(target, value, payload);
        // emit CallExecuted(valveId,id, 0, target, value, payload);
        _afterCall(valveId,id);
    }

    /**
     * @dev Execute an (ready) operation containing a batch of transactions.
     *
     * Emits one {CallExecuted} event per transaction in the batch.
     *
     * Requirements:
     *
     * - the caller must have the 'executor' role.
     */
    function executeBatch(
        uint256 valveId,
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt
    ) public payable virtual onlyRoleOrOpenRole(EXECUTOR_ROLE) {
        require(targets.length == values.length, "ValveControllerMulti: length mismatch");
        require(targets.length == payloads.length, "ValveControllerMulti: length mismatch");

        bytes32 id = hashOperationBatch(valveId,targets, values, payloads, predecessor, salt);
        
        ValveController _valveController = ValveController(_valves[valveId]);
        
        _beforeCall(valveId,id, predecessor);
        for (uint256 i = 0; i < targets.length; ++i) {
            address target = targets[i];
            uint256 value = values[i];
            bytes calldata payload = payloads[i];
            // _execute(target, value, payload);
            _valveController.execute(target, value, payload, predecessor, salt);
            // emit CallExecuted(valveId, id, i, target, value, payload);
        }
        _afterCall(valveId,id);
    }

    /**
     * @dev Execute an operation's call.
     */
    function _execute(
        address target,
        uint256 value,
        bytes calldata data
    ) internal virtual {
        (bool success, ) = target.call{value: value}(data);
        require(success, "ValveControllerMulti: underlying transaction reverted");
    }

    /**
     * @dev Checks before execution of an operation's calls.
     */
    function _beforeCall(uint256 valveId,bytes32 id, bytes32 predecessor) private view {
        require(isOperationReady(valveId,id), "ValveControllerMulti: operation is not ready");
        require(
            predecessor == bytes32(0) || isOperationDone(valveId,predecessor), 
            "ValveControllerMulti: missing dependency"
        );
    }

    /**
     * @dev Checks after execution of an operation's calls.
     */
    function _afterCall(uint256 valveId,bytes32 id) private {
        require(isOperationReady(valveId,id), "ValveControllerMulti: operation is not ready");
        _timestamps[valveId][id] = _DONE_TIMESTAMP;
    }

    /**
     * @dev Changes the minimum timelock duration for future operations.
     *
     * Emits a {MinDelayChange} event.
     *
     * Requirements:
     *
     * - the caller must be the timelock itself. This can only be achieved by scheduling and later executing
     * an operation where the timelock is the target and the data is the ABI-encoded call to this function.
     */
    function updateDelay(uint256 newDelay) external virtual {
        require(msg.sender == address(this), "ValveControllerMulti: caller must be valve");
        emit MinDelayChange(_minDelay, newDelay);
        _minDelay = newDelay;
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
