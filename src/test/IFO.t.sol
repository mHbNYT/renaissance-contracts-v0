//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import {Settings} from "../contracts/Settings.sol";
import {FNFTFactory, ERC721Holder} from "../contracts/FNFTFactory.sol";
import {IFOFactory} from "../contracts/IFOFactory.sol";
import {FNFT} from "../contracts/FNFT.sol";
import {IFO} from "../contracts/IFO.sol";
import {MockNFT} from "../contracts/mocks/NFT.sol";
import {WETH} from "../contracts/mocks/WETH.sol";
import {console} from "./utils/console.sol";
import {CheatCodes} from "./utils/cheatcodes.sol";
import {User, UserNoETH, Curator} from "./utils/user.sol";

/// @author Nibble Market
/// @title Tests for the fnfts
contract IFOTest is DSTest, ERC721Holder {
    CheatCodes public vm;

    FNFTFactory public fnftFactory;
    IFOFactory public ifoFactory;
    Settings public settings;
    MockNFT public token;
    FNFT public fnft;
    IFO public ifo;

    User public user1;
    User public user2;
    User public user3;

    UserNoETH public user4;

    Curator public curator;

    function setUp() public {
        vm = CheatCodes(HEVM_ADDRESS);

        settings = new Settings();

        settings.setGovernanceFee(10);

        fnftFactory = new FNFTFactory(address(settings));
        ifoFactory = new IFOFactory(address(settings));

        token = new MockNFT();

        token.mint(address(this), 1);

        token.setApprovalForAll(address(fnftFactory), true);
        fnftFactory.mint("testName", "TEST", address(token), 1, 100e18, 100 ether, 50);

        fnft = FNFT(fnftFactory.fnfts(0));

        vm.etch(fnft.weth(), type(WETH).creationCode);

        // create a curator account
        curator = new Curator(address(fnftFactory));

        // create 3 users and provide funds through HEVM store
        user1 = new User(address(fnft));
        user2 = new User(address(fnft));
        user3 = new User(address(fnft));
        user4 = new UserNoETH(address(fnft));

        payable(address(user1)).transfer(10 ether);
        payable(address(user2)).transfer(10 ether);
        payable(address(user3)).transfer(10 ether);
        payable(address(user4)).transfer(10 ether);
    }

    function testpause() public {
        ifoFactory.pause();
        ifoFactory.unpause();

        ifoFactory.create(address(fnft), 100e18, 1 ether, 1 ether, false);
    }

    function testFail_pause() public {
        ifoFactory.pause();

        ifoFactory.create(address(fnft), 100e18, 1 ether, 1 ether, false);
    }
}