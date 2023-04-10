// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (governance/extensions/GovernorVotes.sol)

pragma solidity ^0.8.0;

import "../../GovernorMulti.sol";
import "../../utils/IVotesMulti.sol";

/**
 * @dev Extension of {Governor} for voting weight extraction from an {ERC20Votes} token, 
 * or since v4.5 an {ERC721Votes} token.
 *
 * _Available since v4.3._
 */
abstract contract GovernorVotesMulti is GovernorMulti {
    IVotesMulti public immutable token;

    constructor(IVotesMulti tokenAddress) {
        token = tokenAddress;
    }

    /**
     * Read the voting weight from the token's built in snapshot mechanism (see {Governor-_getVotes}).
     */
    function _getVotes(
        address account,
        uint256 id, 
        uint256 blockNumber,
        bytes memory /*params*/
    ) internal view virtual override returns (uint256) {
        return token.getPastVotes(account,id, blockNumber);
    }
}
