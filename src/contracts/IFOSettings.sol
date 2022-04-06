//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IIFOSettings.sol";

contract IFOSettings is Ownable, IIFOSettings {
    /// @notice the boolean whether creator should have access to the creator's fNFT shares after IFO
    bool public override creatorIFOLock;
    uint256 public override minimumDuration;
    uint256 public override maximumDuration;
    address public override creatorUtilityContract;

    event UpdateCreatorIFOLock(bool _lock);
    event UpdateMinimumDuration(uint256 _blocks);
    event UpdateMaximumDuration(uint256 _blocks);
    event UpdateCreatorUtilityContract(address _utility);

    error ZeroAddressDisallowed();

    constructor() {
        creatorIFOLock = false;
        minimumDuration = 86400; // 1 day;
        maximumDuration = 7776000; // 90 days;
    }

    function setCreatorIFOLock(bool _lock) external onlyOwner {
        emit UpdateCreatorIFOLock(_lock);

        creatorIFOLock = _lock;
    }

    function setMinimumDuration(uint256 _blocks) external onlyOwner {
        emit UpdateMinimumDuration(_blocks);

        minimumDuration = _blocks;
    }

    function setMaximumDuration(uint256 _blocks) external onlyOwner {
        emit UpdateMaximumDuration(_blocks);

        maximumDuration = _blocks;
    }

    function setCreatorUtilityContract(address _utility) external onlyOwner {
        if (_utility == address(0)) revert ZeroAddressDisallowed();        

        emit UpdateCreatorUtilityContract(_utility);

        creatorUtilityContract = _utility;
    }
}
