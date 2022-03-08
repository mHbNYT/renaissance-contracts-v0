//SPDX-License-Identifier: MIT
pragma solidity 0.8.11;
import "ds-test/test.sol";
import "./utils/cheatcodes.sol";
import {MockNFT} from "../contracts/mocks/NFT.sol";
import {FNFTController} from "../contracts/fNFTController.sol";
import {Fractionalizer} from "../contracts/Fractionalizer.sol";
import {FNFTERC20} from "../contracts/fNFTERC20.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract testFractionalizer is DSTest, ERC721Holder {
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

    function testFractionalize(uint224 fractions, uint256 reservePrice) public {
        uint256 tokenId = 1;
        address computedFNFTAddress = fractionalizer.computeFNFTAddress(
            address(this),
            address(nft),
            tokenId,
            fractions,
            reservePrice
        );
        nft.safeMint(address(this));
        nft.approve(address(fractionalizer), tokenId);

        fNFT = fractionalizer.fractionalize(address(nft), tokenId, fractions, reservePrice);
        assertEq(computedFNFTAddress, address(fNFT));
        assertEq(fNFT.creator(), address(this));
        assertEq(address(fNFT.nft()), address(nft));
        assertEq(fNFT.name(), "Fractionalized MockNFT");
        assertEq(fNFT.symbol(), "fNFT-MOCK-#1");
        assertEq(fNFT.totalSupply(), fractions);
        assertEq(fNFT.reservePrice(), reservePrice);
        assertEq(nft.ownerOf(tokenId), address(fNFT));
    }
}
