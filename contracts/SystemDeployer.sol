// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./deployers/interfaces/IGovernanceTokenDeployer.sol";
import "./deployers/interfaces/IValveMultiDeployer.sol";
import "./deployers/interfaces/IGovernorContractMultiDeployer.sol";
import "./ValveFactory.sol";

/**
 * @dev Main contract in the deployment of the system
 */
contract SystemDeployer is AccessControl {
    address public governanceToken;
    address public valveMulti;
    address public governorContractMulti;
    address public valveFactory;

    address public governanceTokenDeployer;
    address public valveMultiDeployer;
    address public governorContractMultiDeployer;

    address public valveLogic;

    struct DeployDataValveMulti {
        uint256 minDelay;
        address[] proposers;
        address[] executors;
    }

    event LogSystemAddresses(
        address governanceToken,
        address valveMulti,
        address governorContractMulti,
        address valveFactory
    );

    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Only admin");
        _;
    }
    /**
     * @dev Sets the value for {valveLogic} and gives admin role to deployer
     * @param _valveLogic Address of the Valve
     */
    constructor(address _valveLogic) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        valveLogic = _valveLogic;
    }

    /**
     * @dev Sets the new {valveLogic}
     * @param _valveLogic Address of the new Valve
     */
    function setValveLogic(address _valveLogic) public onlyAdmin {
        valveLogic = _valveLogic;
    }

    /** 
     * @dev Sets the addresses for {governcanceTokenDeployer}, {valveMultiDeployer} and 
     * {governorContractMultiDeployer}
     * @param _governanceTokenDeployer Address of the GovernanceTokenDeployer
     * @param _valveMultiDeployer Address of the ValveMultiDeployer
     * @param _governorContractMultiDeployer Address of the GovernorContractMultiDeployer
    */
    function setDeployers(
        address _governanceTokenDeployer,
        address _valveMultiDeployer,
        address _governorContractMultiDeployer
    ) public onlyAdmin {
        governanceTokenDeployer = _governanceTokenDeployer;
        valveMultiDeployer = _valveMultiDeployer;
        governorContractMultiDeployer = _governorContractMultiDeployer;
    }

    /**
     * @dev Main function that deploys all system
     * @param _valveData Struct with data for valveMulti deployment
     */
    function deploySystem(
        DeployDataValveMulti calldata _valveData
    ) public onlyAdmin {
        IGovernanceTokenDeployer(governanceTokenDeployer)
            .createGovernanceTokenMulti();
        governanceToken = IGovernanceTokenDeployer(governanceTokenDeployer)
            .getGovernanceToken();

        IValveMultiDeployer(valveMultiDeployer).createValveMulti(
            _valveData.minDelay,
            _valveData.proposers,
            _valveData.executors
        );
        valveMulti = IValveMultiDeployer(valveMultiDeployer)
            .getValveMulti();

        IGovernorContractMultiDeployer(governorContractMultiDeployer)
            .createGovernorContractMulti(
                governanceToken,
                payable(valveMulti)
            );
        governorContractMulti = IGovernorContractMultiDeployer(
            governorContractMultiDeployer
        ).getGovernorContractMulti();

        valveFactory = address(
            new ValveFactory(
                governanceToken,
                valveLogic,
                valveMulti,
                msg.sender
            )
        );

        emit LogSystemAddresses(
            governanceToken,
            valveMulti,
            governorContractMulti,
            valveFactory
        );
    }

    /**
     * @dev Sets up ValveMulti Deployer
     */
    function setUpContracts() public onlyAdmin {
        IValveMultiDeployer(valveMultiDeployer).setUpContract(
            governorContractMulti
        );
    }
}
