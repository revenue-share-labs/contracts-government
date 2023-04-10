pragma solidity ^0.8.0;

import "../token/GovernanceTokenMulti.sol";

/**
 * @dev Part of the deployment system.
 * This contract is designed for GovernanceToken deployment 
 */
contract GovernanceTokenDeployer {
    GovernanceTokenMulti public governanceToken;

    /**
     * @dev Main function that deploys GovernanceToken
     */
    function createGovernanceTokenMulti() public {
        governanceToken = new GovernanceTokenMulti();
    }
    /**
     * @dev Returns address of the last deployed GovernanceToken
     */
    function getGovernanceToken() public view returns (address) {
        return (address(governanceToken));
    }
}