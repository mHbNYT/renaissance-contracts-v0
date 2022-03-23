//SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import {FNFTController} from "./fNFTController.sol";
import {FNFTERC20} from "./fNftERC20.sol";
import "../test/utils/console.sol";

contract Fractionalizer is Ownable {
    event Fractionalized(address FNFTAddress, address nft, uint256 tokenId, uint256 fractions, uint256 reservePrice);

    bytes4 public immutable salt = 0xefefefef;

    FNFTController public controller;

    constructor(address _controller) {
        controller = FNFTController(_controller);
    }

    function fractionalize(
        address _nft,
        uint256 _tokenId,
        uint224 _fractions,
        uint256 _reservePrice
    ) public returns (FNFTERC20) {
        // emit the event before the creation of the contract for subgraph reasons

        FNFTERC20 fNFT = new FNFTERC20{salt: bytes32(salt)}(
            msg.sender,
            _nft,
            _tokenId,
            _fractions,
            _reservePrice,
            controller
        );
        ERC721(_nft).safeTransferFrom(msg.sender, address(fNFT), _tokenId);

        emit Fractionalized(address(fNFT), _nft, _tokenId, _fractions, _reservePrice);
        return fNFT;
    }

    function computeFNFTAddress(
        address _owner,
        address _nft,
        uint256 _tokenId,
        uint224 _fractions,
        uint256 _reservePrice
    ) public view returns (address) {
        return
            address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(
                                bytes1(0xff),
                                address(this),
                                bytes32(salt),
                                keccak256(
                                    abi.encodePacked(
                                        type(FNFTERC20).creationCode,
                                        abi.encode(_owner, _nft, _tokenId, _fractions, _reservePrice, controller)
                                    )
                                )
                            )
                        )
                    )
                )
            );
    }
}
