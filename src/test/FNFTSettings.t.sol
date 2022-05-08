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

    // too high
    function testFail_setMaxAuction() public {
        fnftSettings.setMaxAuctionLength(10 weeks);
    }

    // lower than min auction length
    function testFail_setMaxAuction2() public {
        fnftSettings.setMaxAuctionLength(2.9 days);
    }

    function test_setMinAuction() public {
        fnftSettings.setMinAuctionLength(1 weeks);
    }

    // too low
    function testFail_setMinAuction() public {
        fnftSettings.setMaxAuctionLength(0.1 days);
    }

    // higher than max auction length
    function testFail_setMinAuction2() public {
        fnftSettings.setMinAuctionLength(5 weeks);
    }

    function test_setGovernanceFee() public {
        fnftSettings.setGovernanceFee(90);
    }

    // too high
    function testFail_setGovernanceFee() public {
        fnftSettings.setGovernanceFee(110);
    }

    function test_setMinBidIncrease() public {
        fnftSettings.setMinBidIncrease(75);
    }

    // too high
    function testFail_setMinBidIncrease2() public {
        fnftSettings.setMinBidIncrease(110);
    }

    // too low
    function testFail_setMinBidIncrease() public {
        fnftSettings.setMinBidIncrease(5);
    }

    function test_setMaxReserveFactor() public {
        fnftSettings.setMaxReserveFactor(10000);
    }

    // lower than min
    function testFail_setMaxReserveFactor() public {
        fnftSettings.setMaxReserveFactor(200);
    }

    function test_setMinReserveFactor() public {
        fnftSettings.setMinReserveFactor(400);
    }

    // higher than max
    function testFail_setMinReserveFactor() public {
        fnftSettings.setMinReserveFactor(6000);
    }

    function test_setFeeReceiver() public {
        fnftSettings.setFeeReceiver(payable(address(this)));
    }
}
