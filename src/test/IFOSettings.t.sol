//solhint-disable func-name-mixedcase
//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";

import "../contracts/IFOSettings.sol";
import "../contracts/mocks/NFT.sol";
import {console, CheatCodes, SetupEnvironment} from "./utils/utils.sol";
import {Deployer} from "../contracts/proxy/Deployer.sol";


/// @author andy8052
/// @title Tests for the ifoSettings
contract IFOSettingsTest is DSTest, SetupEnvironment {
    IFOSettings public ifoSettings;

    function setUp() public {
        setupEnvironment(10 ether);
        (, , ifoSettings, , , , ) = setupContracts(10 ether);        
    }

    function test_setCreatorIFOLock() public {
        ifoSettings.setCreatorIFOLock(true);
        assertTrue(ifoSettings.creatorIFOLock());
    }

    function test_setMinimumDuration() public {
        ifoSettings.setMinimumDuration(0);
        assertEq(ifoSettings.minimumDuration(), 0);
    }

    function test_setMaximumDuration() public {
        ifoSettings.setMaximumDuration(86401);
        assertEq(ifoSettings.maximumDuration(), 86401);
    }

    function testFail_invalidMinimumDuration() public {
        ifoSettings.setMaximumDuration(86401);
        ifoSettings.setMinimumDuration(86402);
    }

    function testFail_invalidMaximumDuration() public {
        ifoSettings.setMaximumDuration(ifoSettings.minimumDuration() - 1);
    }

    function test_setCreatorUtilityContract() public {
        ifoSettings.setCreatorUtilityContract(address(1));
        assertEq(ifoSettings.creatorUtilityContract(), address(1));

        ifoSettings.setCreatorUtilityContract(address(0));
        assertEq(ifoSettings.creatorUtilityContract(), address(0));
    }

    function test_setGovernanceFee() public {
        ifoSettings.setGovernanceFee(100);
        assertEq(ifoSettings.governanceFee(), 100);
    }

    function testFail_setGovernanceFee() public {
        ifoSettings.setGovernanceFee(101);        
    }

    function test_setFeeReceiver() public {
        ifoSettings.setFeeReceiver(payable(address(1)));
        assertEq(ifoSettings.feeReceiver(), payable(address(1)));
    }

    function testFail_setFeeReceiver() public {
        ifoSettings.setFeeReceiver(payable(address(0)));
    }
}
