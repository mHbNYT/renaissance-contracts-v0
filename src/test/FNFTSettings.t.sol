//solhint-disable func-name-mixedcase
//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";

import "../contracts/FNFTSettings.sol";
import "../contracts/mocks/NFT.sol";
import {console, CheatCodes, SetupEnvironment} from "./utils/utils.sol";


/// @author andy8052
/// @title Tests for the fnftSettings
contract FNFTSettingsTest is DSTest, SetupEnvironment {
    FNFTSettings public fnftSettings;
    MockNFT public token;
    MockNFT public token2;

    function setUp() public {
        setupEnvironment(10 ether);
        (, , , , fnftSettings, , ) = setupContracts(10 ether);

        token = new MockNFT();
        token2 = new MockNFT();
    }

    function test_setMaxAuction() public {
        fnftSettings.setMaxAuctionLength(4 weeks);
        assertEq(fnftSettings.maxAuctionLength(), 4 weeks);
    }

    function testSetMaxAuctionLengthTooHigh() public {
        vm.expectRevert(FNFTSettings.MaxAuctionLengthTooHigh.selector);
        fnftSettings.setMaxAuctionLength(10 weeks);
    }

    function testSetMaxAuctionLengthTooLow() public {
        vm.expectRevert(FNFTSettings.MaxAuctionLengthTooLow.selector);
        fnftSettings.setMaxAuctionLength(2.9 days);
    }

    function test_setMinAuction() public {
        fnftSettings.setMinAuctionLength(1 weeks);
    }

    function testSetMinAuctionLengthTooLow() public {
        vm.expectRevert(FNFTSettings.MinAuctionLengthTooLow.selector);
        fnftSettings.setMinAuctionLength(0.1 days);
    }

    function testSetMinAuctionLengthTooHigh() public {
        vm.expectRevert(FNFTSettings.MinAuctionLengthTooHigh.selector);
        fnftSettings.setMinAuctionLength(5 weeks);
    }

    function test_setGovernanceFee() public {
        fnftSettings.setGovernanceFee(1000);
    }

    // too high
    function testSetGovernanceFeeTooHigh() public {
        vm.expectRevert(FNFTSettings.GovFeeTooHigh.selector);
        fnftSettings.setGovernanceFee(1001);
    }

    function test_setMinBidIncrease() public {
        fnftSettings.setMinBidIncrease(75);
    }

    // too high
    function testSetMinBidIncreaseTooHigh() public {
        vm.expectRevert(FNFTSettings.MinBidIncreaseTooHigh.selector);
        fnftSettings.setMinBidIncrease(110);
    }

    // too low
    function testSetMinBidIncreaseTooLow() public {
        vm.expectRevert(FNFTSettings.MinBidIncreaseTooLow.selector);
        fnftSettings.setMinBidIncrease(5);
    }

    function test_setMaxReserveFactor() public {
        fnftSettings.setMaxReserveFactor(10000);
    }

    function testSetMaxReserveFactorTooLow() public {
        vm.expectRevert(FNFTSettings.MaxReserveFactorTooLow.selector);
        fnftSettings.setMaxReserveFactor(200);
    }

    function test_setMinReserveFactor() public {
        fnftSettings.setMinReserveFactor(400);
    }

    function testSetMaxReserveFactorTooHigh() public {
        vm.expectRevert(FNFTSettings.MinReserveFactorTooHigh.selector);
        fnftSettings.setMinReserveFactor(6000);
    }

    function test_setFeeReceiver() public {
        fnftSettings.setFeeReceiver(payable(address(this)));
    }
}
