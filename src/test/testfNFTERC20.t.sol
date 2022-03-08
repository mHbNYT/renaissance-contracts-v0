//SPDX-License-Identifier: MIT
pragma solidity 0.8.11;
import "ds-test/test.sol";
import "./utils/cheatcodes.sol";

contract OwnerUpOnly {
    address public immutable owner;
    uint256 public count;

    constructor() {
        owner = msg.sender;
    }

    function increment() external {
        require(msg.sender == owner, "only the owner can increment the count");
        count++;
    }
}

contract estfNFT is DSTest {
    CheatCodes public cheats = CheatCodes(HEVM_ADDRESS);
    OwnerUpOnly upOnly;

    function setUp() public {
        upOnly = new OwnerUpOnly();
    }

    function testIncrementAsOwner() public {
        assertEq(upOnly.count(), 0);
        cheats.expectRevert(bytes("only the owner can increment the count"));
        cheats.prank(address(0));
        upOnly.increment();
        assertEq(upOnly.count(), 0);
    }
}
