// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./interfaces/IGovernanceTokenMulti.sol";
import "./interfaces/IValveMulti.sol";

/**
 * @dev This contract is created by SystemDeployer contract and is part of RSC.
 * 
 * Contract is designed for Valve deployment and governance token distribution
 */
contract ValveFactory is AccessControl {
  address public governanceToken;
  address public valveLogic;
  address public valveMulti;
  uint256 public valveIndex = 0;

  mapping(uint256 => address) public indexToValve;

  struct ValveInitData {
    uint256 minDelay;
    address[] proposers;
    address[] executors;
  }

  struct TransferData {
    address to;
    uint256 index;
    uint256 ids;
    uint256 amount;
  }

  modifier onlyAdmin() {
    require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Only admin");
    _;
  }
    /**
     * @dev Sets the value for {governanceToken}, {valveLogic} and {valveMulti}.
     * Give the admin role for {admin}
     */
  constructor(
    address _governanceToken,
    address _valveLogic,
    address _valveMulti,
    address admin
  ) {
    governanceToken = _governanceToken;
    valveLogic = _valveLogic;
    valveMulti = _valveMulti;
    _grantRole(DEFAULT_ADMIN_ROLE, admin);
  }

  /**
   * @dev Sets the new governance token
   * @param _governanceToken Address of the new governance token
   */
  function setGovernanceToken(address _governanceToken) public onlyAdmin {
    governanceToken = _governanceToken;
  }

  /**
   * @dev Sets the new Valve contract
   * @param _newValveLogic Address of the new Valve contract
   */
  function setValveLogic(address _newValveLogic) public onlyAdmin {
    valveLogic = _newValveLogic;
  }

  /**
   * @dev Sets the new ValveMulti Contract
   * @param _valveMulti Address of the new ValveMulti contract
   */
  function setValveMulti(address _valveMulti) public onlyAdmin {
    valveMulti = _valveMulti;
  }

  /**
   * @dev The main function that deploys proxy contracts implementing Valve contract logic
   *      and mint governance tokens to the specified addresses from {_transferData}
   * @param _valveInitData Struct with initialization data for Valve
   * @param _transferData Struct with data for mint governance tokens
   */
  function deployValve(
    ValveInitData[] calldata _valveInitData,
    TransferData[] calldata _transferData
  ) public {
    for (uint256 i = 0; i < _valveInitData.length; ) {
      bytes memory initializeCall = abi.encodeWithSignature(
        "initialize(address,uint256,uint256,address,address[],address[])",
        governanceToken,
        valveIndex,
        _valveInitData[i].minDelay,
        msg.sender,
        _valveInitData[i].proposers,
        _valveInitData[i].executors
      );
      ERC1967Proxy valveProxy = new ERC1967Proxy{salt: bytes32(valveIndex)}(
        valveLogic,
        initializeCall
      );
      indexToValve[valveIndex] = address(valveProxy);
      IValveMulti(valveMulti).setValve(valveIndex, address(valveProxy));
      valveIndex += 1;
      unchecked {
        i++;
      }
    }
    for (uint256 i = 0; i < _transferData.length; ) {
      address toMint;
      if (_transferData[i].to == address(0)) {
        toMint = indexToValve[_transferData[i].index];
      } else {
        toMint = _transferData[i].to;
      }

      IGovernanceTokenMulti(governanceToken).mint(
        toMint,
        _transferData[i].ids,
        _transferData[i].amount,
        ""
      );
      unchecked {
        i++;
      }
    }
  }
}
