// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./Utils.sol";

// contract MyBook is ERC1155, Ownable, Pausable, Utils, GovernorContractMulti {
contract MyBook is ERC1155, Ownable, Pausable, Utils {

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    
    constructor() ERC1155("") {}

    mapping(uint256 => Percent[]) public percents;
    mapping(uint256 => uint256) public sumPercents;
    // mapping (uint256 => GovernorContract) public governances;  // ???

    function returnPercents(uint256 index) external view returns(Percent[] memory){
        return percents[index];    
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address account, uint256 id, uint256 amount, bytes memory data)
        public
        onlyOwner
    {
        require(sumPercents[id]+amount <= 10**6, "Max token supply is 10**6");
        sumPercents[id] += amount;
        _mint(account, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        public
        onlyOwner
    {
        _mintBatch(to, ids, amounts, data);
    }

    

    function _beforeTokenTransfer(
        address operator, 
        address from, 
        address to, 
        uint256[] memory ids, 
        uint256[] memory amounts, 
        bytes memory data
    ) internal whenNotPaused override {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
        for (uint256 i = 0; i < ids.length;){
            for (uint256 j = 0; j < percents[ids[i]].length;){
                if (percents[ids[i]][j].addr == from){
                    percents[ids[i]][j].percent -= amounts[i];
                }
                else if (percents[ids[i]][j].addr == to) {
                    percents[ids[i]][j].percent += amounts[i];
                }
                unchecked{j++;}
                
            }
            percents[ids[i]].push(Percent(to, amounts[i]));
            unchecked{i++;}
        } 
    }

    function current() external view returns(uint256){
        return _tokenIdCounter.current();
    }
}