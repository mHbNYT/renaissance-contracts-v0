// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract FNFTController is Ownable {
    // num of blocks per hour on n network (aurora is ~3000)
    uint256 public blocksPerHour;
    // percentage of holders needed to reach quorum
    uint256 public quorumPercentage;
    uint256 public startingBidCooldownHours;
    uint256 public bidCooldownHours;
    uint256 public proposalExpiraryHours;

    constructor(
        uint256 _blocksPerHour,
        uint256 _quorumPercentage,
        uint256 _startingBidCooldownHours,
        uint256 _bidCooldownHours,
        uint256 _proposalExpiraryHours
    ) {
        blocksPerHour = _blocksPerHour;
        quorumPercentage = _quorumPercentage;
        startingBidCooldownHours = _startingBidCooldownHours;
        bidCooldownHours = _bidCooldownHours;
        proposalExpiraryHours = _proposalExpiraryHours;
    }

    function getBidExpirary(bool _isStartingBid) public view returns (uint256) {
        return block.number + ((blocksPerHour * 24) * (_isStartingBid ? startingBidCooldownHours : bidCooldownHours));
    }
}
