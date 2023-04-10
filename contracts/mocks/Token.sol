// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20{
    address public owner;

    constructor () ERC20("Test", "Test"){
        _mint(msg.sender, 10**24);
        owner = msg.sender;
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

}