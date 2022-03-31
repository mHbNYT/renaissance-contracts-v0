//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import {IFNFTSettings, FNFTSettings} from "../contracts/FNFTSettings.sol";
import {IPriceOracle} from "../contracts/interfaces/IPriceOracle.sol";
import {FNFTFactory, ERC721Holder} from "../contracts/FNFTFactory.sol";
import {IFOFactory} from "../contracts/IFOFactory.sol";
import {FNFT} from "../contracts/FNFT.sol";
import {IFO} from "../contracts/IFO.sol";
import {MockNFT} from "../contracts/mocks/NFT.sol";
import {WETH} from "../contracts/mocks/WETH.sol";
import {console, CheatCodes, SetupEnvironment, User, Curator, UserNoETH} from "./utils/utils.sol";

/// @author Nibble Market
/// @title Tests for the fnfts
contract IFOTest is DSTest, ERC721Holder {
    CheatCodes public vm;

    FNFTFactory public fnftFactory;
    IFOFactory public ifoFactory;
    FNFTSettings public fNFTSettings;
    WETH public weth;
    IPriceOracle public priceOracle;
    MockNFT public nft;
    FNFT public fnft;
    IFO public ifo;

    User public user1;
    User public user2;
    User public user3;

    UserNoETH public user4;

    Curator public curator;

    function setUp() public {
        (vm, weth, , priceOracle) = SetupEnvironment.setup();

        fNFTSettings = new FNFTSettings(address(weth), address(priceOracle));
        fNFTSettings.setGovernanceFee(10);

        fnftFactory = new FNFTFactory(address(fNFTSettings));
        ifoFactory = new IFOFactory(address(fNFTSettings));

        nft = new MockNFT();

        nft.mint(address(this), 1);

        nft.setApprovalForAll(address(fnftFactory), true);
        fnft = FNFT(fnftFactory.mint("testName", "TEST", address(nft), 1, 100e18, 100 ether, 50));

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

    function testPause() public {
        // ifoFactory.pause();
        // ifoFactory.unpause();
        // fnft.transfer(address(ifoFactory), 10 ether);
        // ifoFactory.create(address(fnft), 100 ether, 1 ether, 1 ether, false);
    }

    function testCannotCreateWhenPaused() public {
        //     // ifoFactory.pause();
        //     // vm.expectRevert(bytes("Pausable: paused"));
        //     ifoFactory.create(address(fnft), 100e18, 1 ether, 1 ether, false);
    }
}
