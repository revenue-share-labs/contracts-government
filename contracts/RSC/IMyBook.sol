// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Utils.sol";

interface IMyBook {
    function returnPercents(uint256) external view returns(Utils.Percent[] memory);
}
