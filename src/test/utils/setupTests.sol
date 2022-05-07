// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "../../../lib/ds-test/src/test.sol";
import {CheatCodes} from "./cheatcodes.sol";
import {WETH} from "../../contracts/mocks/WETH.sol";
import {PriceOracle} from "../../contracts/PriceOracle.sol";
import {IFOSettings} from "../../contracts/IFOSettings.sol";
import {IFOFactory} from "../../contracts/IFOFactory.sol";
import {FNFTSettings} from "../../contracts/FNFTSettings.sol";
import {FNFTFactory} from "../../contracts/FNFTFactory.sol";
import {IUniswapV2Factory} from "../../contracts/interfaces/IUniswapV2Factory.sol";
import {IFNFT} from "../../contracts/interfaces/IFNFT.sol";
import {FNFTFactory} from "../../contracts/FNFTFactory.sol";
import {FNFT} from "../../contracts/FNFT.sol";
import {MockNFT} from "../../contracts/mocks/NFT.sol";

library SetupEnvironment {
    function setupWETH(uint256 _amountToMint) public returns (WETH weth) {
        weth = new WETH(_amountToMint);
    }

    function setupPairFactory() public pure returns (IUniswapV2Factory v2Factory) {
        v2Factory = IUniswapV2Factory(0xc66F594268041dB60507F00703b152492fb176E7);
    }

    function setupPriceOracle(address v2Factory, address weth) public returns (PriceOracle priceOracle) {
        priceOracle = new PriceOracle(v2Factory, weth);
    }

    function setupFNFTSettings(address _weth, address _priceOracle) public returns (FNFTSettings fNFTSettings) {
        address ifoFactory = address(new IFOFactory(address(new IFOSettings())));
        fNFTSettings = new FNFTSettings(address(_weth), address(_priceOracle), ifoFactory);
        fNFTSettings.setGovernanceFee(10);
    }

    function setupFNFTFactory(address _fNFTSettings) public returns (FNFTFactory fNFTFactory) {
        fNFTFactory = new FNFTFactory(_fNFTSettings);
    }

    function setupFNFT(address _fNFTFactory, uint256 _amountToMint) public returns (FNFT fNFT) {
        FNFTFactory factory = FNFTFactory(_fNFTFactory);

        MockNFT token = new MockNFT();

        token.mint(address(this), 1);

        token.setApprovalForAll(_fNFTFactory, true);
        
        // FNFT minted on this test contract address.
        fNFT = FNFT(factory.mint("testName", "TEST", address(token), 1, _amountToMint, 1 ether, 50));
    }
   
    function setup(uint256 _fNFTAmount, uint256 _wethAmount)
        public
        returns (
            CheatCodes vm,
            WETH weth,
            IUniswapV2Factory pairFactory,
            PriceOracle priceOracle,
            FNFTSettings fNFTSettings,
            FNFTFactory fNFTFactory,
            FNFT fNFT
        )
    {
        vm = CheatCodes(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));
        weth = setupWETH(_wethAmount);
        pairFactory = setupPairFactory();
        priceOracle = setupPriceOracle(address(pairFactory), address(weth));
        fNFTSettings = setupFNFTSettings(address(weth), address(priceOracle));
        fNFTFactory = setupFNFTFactory(address(fNFTSettings));
        fNFT = setupFNFT(address(fNFTFactory), _fNFTAmount);
    }
}
