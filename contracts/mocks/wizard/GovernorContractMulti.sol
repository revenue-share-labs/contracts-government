// // SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../../governance/GovernorMulti.sol";
import "../../governance/extensions/multi/GovernorCountingSimpleMulti.sol";
import "../../governance/extensions/multi/GovernorVotesMulti.sol";
import "../../governance/extensions/multi/GovernorVotesQuorumFractionMulti.sol";
import "../../governance/extensions/multi/GovernorValveControlMulti.sol";
import "../../governance/extensions/multi/GovernorSettingsMulti.sol";

/**
 * @dev Core of the governance system
 */
contract GovernorContractMulti is
  GovernorMulti,
  GovernorSettingsMulti,
  GovernorCountingSimpleMulti,
  GovernorVotesMulti,
  GovernorVotesQuorumFractionMulti,
  GovernorValveControlMulti
{
  constructor(
    address _token,
    address payable _valve
  )
    GovernorMulti("GovernorContract")
    GovernorSettingsMulti(
      0 // proposal threshold
    )
    GovernorVotesMulti(IVotesMulti(_token))
    GovernorVotesQuorumFractionMulti()
    GovernorValveControlMulti(ValveControllerMulti(_valve)){}

  /**
   * @dev Returns delay for Valve
   * @param index Index of the Valve
   */
  function votingDelay(uint256 index)
    public
    view
    override(IGovernorMulti, GovernorSettingsMulti)
    returns (uint256)
  {
    return super.votingDelay(index);
  }
  /**
   * @dev Returns period of voting
   * @param index Index of the Valve
   */
  function votingPeriod(uint256 index)
    public
    view
    override(IGovernorMulti, GovernorSettingsMulti)
    returns (uint256)
  {
    return super.votingPeriod(index);
  }

  // The following functions are overrides required by Solidity.

  function quorum(uint256 valveId, uint256 blockNumber)
    public
    view
    override(IGovernorMulti, GovernorVotesQuorumFractionMulti)
    returns (uint256)
  {
    return super.quorum(valveId,blockNumber);
  }

  function getVotes(address account, uint256 valveId, uint256 blockNumber)
    public
    view
    override(IGovernorMulti, GovernorMulti)
    returns (uint256)
  {
    return super.getVotes(account, valveId, blockNumber);
  }

  function state(uint256 valveId, uint256 proposalId)
    public
    view
    override(GovernorMulti, GovernorValveControlMulti)
    returns (ProposalStateMulti)
  {
    return super.state(valveId,proposalId);
  }
  
  /**
   * @dev Create a new propose for Valve 
   * @param valveId Index of the Valve
   * @param targets List of addresses to be called
   * @param values List of amounts of ETH to be sent
   * @param calldatas List of calldata to be called
   * @param description Description of the propose
   * @param votingPeriodForIndex Period of the voting 
   * @param votingDelayForIndex Delay of the voting
   */
  function propose(
    uint256 valveId,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    string memory description,
    uint256 votingPeriodForIndex,
    uint256 votingDelayForIndex
  ) public returns (uint256) {
    _setVotingDelay(valveId, votingDelayForIndex);
    _setVotingPeriod(valveId, votingPeriodForIndex);
    return super.propose(valveId,targets, values, calldatas, description);
  }
  /**
   * @dev Part of the Governor Bravo's interface: _"The number of votes required in 
   * order for a voter to become a proposer"_. 
   */
  function proposalThreshold(uint256 index)
    public
    view
    override(GovernorMulti, GovernorSettingsMulti)
    returns (uint256)
  {
    return super.proposalThreshold(index);
  }
  
  function _execute(
    uint256 valveId,
    uint256 proposalId,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) internal override(GovernorMulti, GovernorValveControlMulti) {
    super._execute(valveId,proposalId, targets, values, calldatas, descriptionHash);
  }

  function _cancel(
    uint256 valveId,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) internal override(GovernorMulti, GovernorValveControlMulti) returns (uint256) {
    return super._cancel(valveId,targets, values, calldatas, descriptionHash);
  }

  /**
   * @dev See {IERC165-supportsInterface}.
   */
  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(GovernorMulti, GovernorValveControlMulti)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }
}
