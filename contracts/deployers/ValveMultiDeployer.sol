pragma solidity ^0.8.0;

import "../ValveMulti.sol";

/**
 * @dev Part of the deployment system.
 * This contract is designed for ValveMulti deployment
 */
contract ValveMultiDeployer {
    ValveMulti public valveMulti;

    /**
     * @dev Main function that deploys Valvemulti
     * @param minDelay is how long you have to wait before executing
     * @param proposers List of the proposers addresses
     * @param executors List of the executors addresses
     */
    function createValveMulti(
        uint256 minDelay, 
        address[] calldata proposers,
        address[] calldata executors) 
    public {
        valveMulti = new ValveMulti(minDelay, proposers, executors, address(this));
    }
 
    /**
     * @dev Returns address of the last deployed ValveMulti contract
     */
    function getValveMulti() public view returns (address) {
        return(address(valveMulti));
    }

    /**
     * @dev Set up roles in ValveMulti contract
     * @param governorContractMulti Address of the GovernorContractMutli
     */
    function setUpContract(address governorContractMulti) public {
        require(address(valveMulti) != address(0), "valveMulti can't be zero address");
        require(governorContractMulti != address(0), "governorContractMulti can't be zero address");

        bytes32 proposerRole = valveMulti.PROPOSER_ROLE();
        bytes32 executorRole = valveMulti.EXECUTOR_ROLE();
        bytes32 valveAdminRole = valveMulti.VALVE_ADMIN_ROLE();

        valveMulti.grantRole(proposerRole, address(governorContractMulti));
        valveMulti.grantRole(executorRole, address(governorContractMulti));
        valveMulti.revokeRole(valveAdminRole, address(this));
    }
}