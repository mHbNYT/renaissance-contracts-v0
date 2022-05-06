//solhint-disable func-name-mixedcase
//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";

import "../contracts/IFOSettings.sol";
import "../contracts/mocks/NFT.sol";
import {console, CheatCodes, SetupEnvironment} from "./utils/utils.sol";


/// @author andy8052
/// @title Tests for the settings
contract IFOSettingsTest is DSTest {
    CheatCodes public vm;

    IFOSettings public settings;

    function setUp() public {
        (vm,,,,,,) = SetupEnvironment.setup(10 ether, 10 ether);        

        settings = new IFOSettings();
    }

    function test_setCreatorIFOLock() public {
        settings.setCreatorIFOLock(true);
        assertTrue(settings.creatorIFOLock());
    }

    function test_setMinimumDuration() public {
        settings.setMinimumDuration(0);
        assertEq(settings.minimumDuration(), 0);
    }

    function test_setMaximumDuration() public {
        settings.setMaximumDuration(100);
        assertEq(settings.maximumDuration(), 100);
    }

    function test_setCreatorUtilityContract() public {
        settings.setCreatorUtilityContract(address(1));
        assertEq(settings.creatorUtilityContract(), address(1));

        settings.setCreatorUtilityContract(address(0));
        assertEq(settings.creatorUtilityContract(), address(0));
    }

    function test_setGovernanceFee() public {
        settings.setGovernanceFee(100);
        assertEq(settings.governanceFee(), 100);
    }

    function testFail_setGovernanceFee() public {
        settings.setGovernanceFee(101);        
    }

    function test_setFeeReceiver() public {
        settings.setFeeReceiver(payable(address(1)));
        assertEq(settings.feeReceiver(), payable(address(1)));
    }

    function testFail_setFeeReceiver() public {
        settings.setFeeReceiver(payable(address(0)));
    }
}
