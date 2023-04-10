// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./governance/ValveController.sol";
import "./RSC/IMyBook.sol";
import "./RSC/Utils.sol";

/**
 * @dev This contract is created by ValveFactory contract and is part of RSC. 
 *      Contract is designed for to distribute funds between contracts and user wallets
 */
contract Valve is ValveController {
  IMyBook public book;
  uint256 public index;
  uint256 public sumPercent;
  /**
   * @param _bookAddr Address of the governance token
   * @param _index Index of this Valve
   * @param minDelay is how long you have to wait before executing
   * @param admin ?
   * @param proposers List of addresses that can propose
   * @param executors List of addresses that can execute
   */
  function initialize(
    address _bookAddr,
    uint256 _index,
    uint256 minDelay,
    address admin,
    address[] memory proposers,
    address[] memory executors
  ) public initializer {
    super.initialize(minDelay, proposers, executors, admin);
    book = IMyBook(_bookAddr);
    index = _index;
    sumPercent = 10**6;
  }

  /**
   * @dev This function distribute tokens to the addresses specified in the governance token 
   * @param _token Token that will be distributed
   */
  function split(address _token) public returns (uint256 reminderGas) {
    Utils.Percent[] memory percents = book.returnPercents(index);
    uint256 branchCount = percents.length;
    uint256 startGas = gasleft();

    uint256 lastGasLeft = 0;
    uint256 width = 0;

    if (branchCount > 0) {
      uint256 amount = IERC20(_token).balanceOf(address(this));
      for (uint256 i = 0; i < branchCount; ) {
        IERC20(_token).transfer(percents[i].addr, (amount * percents[i].percent) / sumPercent);
        unchecked {
          i++;
        }
      }

      uint256 remainderGas = gasleft() / 2 / branchCount;

      uint256 _edge = 0;
      for (uint256 i = 0; i < branchCount; ) {
        (bool success, ) = percents[i].addr.call{gas: remainderGas + _edge}(
          abi.encodeWithSignature("Split(address)", _token)
        );
        if (success) {
          width++;
        }
        unchecked {
          i++;
        }
      }

      lastGasLeft = startGas - gasleft();
      reminderGas = startGas - lastGasLeft;
      return reminderGas;
    }
  }
}
