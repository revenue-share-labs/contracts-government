// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../token/ERC1155/extensions/ERC1155Votes.sol";
import "../RSC/Utils.sol";

/**
 * @dev ?
 * 
 */
contract GovernanceTokenMulti is ERC1155Votes {
    uint256 public maxSupply = 1_000_000;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    mapping(uint256 => Utils.Percent[]) public percents;
    mapping(uint256 => uint256) public sumPercents;

    /**
     * @dev Returns struct with contract or wallet address and percent for this address
     * @param index Index of Valve
     */
    function returnPercents(
        uint256 index
    ) external view returns (Utils.Percent[] memory) {
        return percents[index];
    }

    function setURI(string memory newUri) public {
        _setURI(newUri);
    }

    function _maxSupply() internal view virtual override returns (uint224) {
        return uint224(maxSupply);
    }

    function mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public {
        require(sumPercents[id] + amount <= maxSupply, "Max NFT supply is 10**6");
        sumPercents[id] += amount;
        _mint(account, id, amount, data);
    }

    constructor() ERC1155("GovernanceToken") EIP712("GovernanceToken", "0.1") {}

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
        for (uint i = 0; i < ids.length;) {
            bool found = false;
            for (uint j = 0; j < percents[ids[i]].length;) {
                if (percents[ids[i]][j].addr == from) {
                    percents[ids[i]][j].percent -= amounts[i];
                } else if (percents[ids[i]][j].addr == to) {
                    percents[ids[i]][j].percent += amounts[i];
                    found = true;
                }
                unchecked{j++;}
            }
            if (!found) {
                percents[ids[i]].push(Utils.Percent(to, amounts[i]));
            }
            unchecked{i++;}
        }
    }

    function current() external view returns (uint256) {
        return _tokenIdCounter.current();
    }

    function _afterTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override(ERC1155Votes) {
        super._afterTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function _mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual override(ERC1155Votes) {
        super._mint(to, id, amount, data);
        require(
            totalSupply(id) <= _maxSupply(),
            "ERC1155Votes: total supply risks overflowing votes"
        );
    }
}
