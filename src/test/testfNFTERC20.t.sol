//SPDX-License-Identifier: MIT
pragma solidity 0.8.11;
import "ds-test/test.sol";
import "./utils/cheatcodes.sol";
import {MockNFT} from "../contracts/mocks/NFT.sol";
import {FNFTController} from "../contracts/fNFTController.sol";
import {Fractionalizer} from "../contracts/Fractionalizer.sol";
import {FNFTERC20} from "../contracts/fNFTERC20.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "../test/utils/console.sol";

contract testfNFT is DSTest, ERC721Holder {
    CheatCodes public cheats = CheatCodes(HEVM_ADDRESS);
    MockNFT public nft;
    FNFTController public controller;
    Fractionalizer public fractionalizer;
    FNFTERC20 public fNFT;

    constructor() {
        uint256 blocksPerHour = 1;
        uint256 quorumPercentage = 50;
        uint256 startingBidCooldownHours = 2;
        uint256 bidCooldownHours = 1;
        uint256 proposalExpiraryHours = 5;

        nft = new MockNFT();
        controller = new FNFTController(
            blocksPerHour,
            quorumPercentage,
            startingBidCooldownHours,
            bidCooldownHours,
            proposalExpiraryHours
        );
        fractionalizer = new Fractionalizer(address(controller));
    }

    function setUp() public {}

    function testFNFTInitialization(uint224 fractions, uint256 reservePrice) public {
        uint256 tokenId = 1;

        nft.safeMint(address(this));
        nft.approve(address(fractionalizer), tokenId);

        fNFT = fractionalizer.fractionalize(address(nft), tokenId, fractions, reservePrice);
        assertEq(fNFT.name(), "Fractionalized MockNFT");
        assertEq(fNFT.symbol(), "fNFT-MOCK-#1");
        assertEq(fNFT.totalSupply(), fractions);
        assertEq(fNFT.balanceOf(address(this)), fractions);
        assertEq(fNFT.getVotes(address(this)), fractions);
        assertEq(fNFT.reservePrice(), reservePrice);
        assertEq(address(fNFT.nft()), address(nft));
        assertEq(fNFT.creator(), address(this));
        assertTrue(fNFT.contractHasNFT());
        assertTrue(!fNFT.initializing());
        assertEq(address(fNFT.controller()), address(controller));
    }
}
