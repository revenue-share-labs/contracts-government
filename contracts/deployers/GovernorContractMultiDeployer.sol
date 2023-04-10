pragma solidity ^0.8.0;

import "../mocks/wizard/GovernorContractMulti.sol";

/**
 * @dev Part of the deployment system.
 * This contract is designed for GovrenorContractMutli deployment 
 */
contract GovernorContractMultiDeployer {

    GovernorContractMulti public governorContractMulti;

    /**
     * Main function that deploys GovrenorContractMulti
     * @param governanceToken Address of the GovernanceToken
     * @param valveMulti Address of the ValveMutli
     */
    function createGovernorContractMulti(
        address governanceToken,
        address payable valveMulti
    ) public {
        governorContractMulti = new GovernorContractMulti(
            governanceToken,
            valveMulti
        );
    }

    /**
     * @dev Returns address of the last deployed GovernorContractMulti
     */
    function getGovernorContractMulti() public view returns (address){
        return(address(governorContractMulti));
    }
}