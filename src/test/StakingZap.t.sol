// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";
import {SetupEnvironment} from "./utils/utils.sol";
import {StakingZap} from "../contracts/StakingZap.sol";
import {VaultManager} from "../contracts/VaultManager.sol";
import {LPStaking} from "../contracts/LPStaking.sol";
import {FeeDistributor} from "../contracts/FeeDistributor.sol";
import {InventoryStaking} from "../contracts/InventoryStaking.sol";
import {IUniswapV2Router} from "../contracts/interfaces/IUniswapV2Router.sol";

contract StakingZapTest is DSTest, SetupEnvironment {
    IUniswapV2Router private router;
    FeeDistributor private feeDistributor;
    VaultManager private vaultManager;
    StakingZap private stakingZap;
    LPStaking private lpStaking;
    InventoryStaking private inventoryStaking;

    function setUp() public {
        setupEnvironment(10 ether);
        (   ,
            lpStaking,
            ,
            ,
            ,
            feeDistributor,
            vaultManager,
            ,
            ,
            inventoryStaking
        ) = setupContracts();
        router = setupRouter();
        stakingZap = new StakingZap(address(vaultManager), address(router));
        feeDistributor.setInventoryStakingAddress(address(inventoryStaking));
    }

    function testAssignStakingContracts() public {
        assertEq(address(stakingZap.lpStaking()), address(0));
        assertEq(address(stakingZap.inventoryStaking()), address(0));

        stakingZap.assignStakingContracts();

        assertEq(address(stakingZap.lpStaking()), address(lpStaking));
        assertEq(address(stakingZap.inventoryStaking()), address(inventoryStaking));
    }
}