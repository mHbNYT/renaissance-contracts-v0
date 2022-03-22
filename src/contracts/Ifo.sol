// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IfNFT {
    function balanceOf(address _account) external returns(uint256);
    function totalSupply() external returns(uint256);
}

contract Ifo is Ownable {
    using SafeERC20 for IERC20;

    struct UserInfo {
        uint256 amount; // Amount ETH deposited by user
        uint256 debt; // total fNFT claimed thus fNFT debt
    }
    
    IERC20 public FNFT; // fNFT the ifo contract sells
    IERC20 public ETH; // for user deposits
    uint256 public amountForSale; // amount of fNFT for sale
    uint256 public price; // initial price per fNFT
    uint256 public cap; // cap per user
    uint256 public totalRaised; // total ETH raised by sale
    uint256 public totalSold; // total fNFT sold by sale    

    bool public allowWhitelisting; // whether the ifo operates through WL
    bool public started; // true when sale is started
    bool public ended; // true when sale is ended
    bool public contractPaused; // circuit breaker

    uint256 public liquidity = 0; //liquidity deployed by the creator

    mapping(address => UserInfo) public userInfo;
    mapping(address => bool) public whitelisted; // True if user is whitelisted

    event Deposit(address indexed who, uint256 amount, uint256 payout);
    event Withdraw(address token, address indexed who, uint256 amount);
    event Mint(address token, address indexed who, uint256 amount);
    event SaleStarted(uint256 block);
    event SaleEnded(uint256 block);
    event AdminProfitWithdrawal(address _fNFT, uint256 _amount);        
    event AdminETHWithdrawal(address _eth, uint256 _amount);
    event AdminFNFTWithdrawal(address _fNFT, uint256 _amount);
    event LiquidityAdded(uint amountToken, uint amountETH, uint liquidity);
    event LiquidityRemoved(uint amountToken, uint amountETH, uint liquidity);
    
    error InvalidAddress();
    error NotOwner();    
    error InvalidAmountForSale();
    error InvalidPrice();
    error InvalidCap();
    error WhitelistingDisallowed();
    error ContractPaused();
    error TooManyWhitelists();    
    error SaleAlreadyStarted();
    error SaleUnstarted();
    error SaleAlreadyEnded();    
    error SaleActive();
    error TxFailed();
    error NotWhitelisted();
    error OverLimit();
    error NoLiquidityProvided();

    constructor(
        address _fNFT,
        uint256 _amountForSale,
        uint256 _price,
        uint256 _cap,
        bool _allowWhitelisting
    ) {        
        if (_fNFT == address(0)) revert InvalidAddress();
        FNFT = IERC20(_fNFT);
        uint initiatorSupply = IfNFT( address(FNFT) ).balanceOf(msg.sender);
        if (initiatorSupply <= IfNFT( address(FNFT) ).totalSupply()) revert NotOwner();
        if (
            _amountForSale == 0 || 
            _amountForSale > initiatorSupply ||
            _amountForSale % _cap != 0
        ) revert InvalidAmountForSale();        
        if (_price == 0) revert InvalidPrice();        
        if (_cap == 0) revert InvalidCap();

        amountForSale = _amountForSale;        
        price = _price;
        cap = _cap;
        allowWhitelisting = _allowWhitelisting;

        FNFT.safeTransferFrom(msg.sender, address(this), initiatorSupply);
    }

    //* @notice modifer to check if contract is paused
    modifier whitelistingAllowed() {
        if (!allowWhitelisting) revert WhitelistingDisallowed();        
        _;
    }

    //* @notice modifer to check if contract is paused
    modifier checkIfPaused() {
        if (contractPaused) revert ContractPaused();        
        _;
    }

    function updatefNFTAddress(address _address) external onlyOwner {
        FNFT = IERC20(_address);
    } 

    /**
     *  @notice adds a single whitelist to the sale
     *  @param _address: address to whitelist
     */
    function addWhitelist(address _address) external onlyOwner whitelistingAllowed {        
        whitelisted[_address] = true;
    }
    
    /**
     *  @notice adds multiple whitelist to the sale
     *  @param _addresses: dynamic array of addresses to whitelist
     */
    function addMultipleWhitelists(address[] calldata _addresses) external onlyOwner whitelistingAllowed {
        if (_addresses.length > 333) revert TooManyWhitelists();        
        for (uint256 i = 0; i < _addresses.length; i++) {
            whitelisted[_addresses[i]] = true;
        }
    }

    /**
     *  @notice removes a single whitelist from the sale
     *  @param _address: address to remove from whitelist
     */
    function removeWhitelist(address _address) external onlyOwner whitelistingAllowed {
        whitelisted[_address] = false;
    }

    // @notice Starts the sale
    function start() external onlyOwner {        
        if (started) revert SaleAlreadyStarted();
        started = true;
        emit SaleStarted(block.number);
    }

    // @notice Ends the sale
    function end() external onlyOwner {
        if (!started) revert SaleUnstarted();
        if (ended) revert SaleAlreadyEnded();

        ended = true;
        emit SaleEnded(block.number);
    }

    // @notice lets owner pause contract
    function togglePause() external onlyOwner returns (bool){
        contractPaused = !contractPaused;
        return contractPaused;
    }

    /**
     *  @notice it deposits ETH for the sale
     */
    function deposit() external payable checkIfPaused {
        if (!started) revert SaleUnstarted();
        if (ended) revert SaleAlreadyEnded();   
        if (allowWhitelisting == true) {
            if (!whitelisted[msg.sender]) revert NotWhitelisted();            
        }

        UserInfo storage user = userInfo[msg.sender];
        if (user.amount + msg.value > cap) revert OverLimit();        

        user.amount = user.amount + msg.value;
        totalRaised = totalRaised + msg.value;

        uint256 payout = msg.value * 1e18 / price / 1e18; // fNFT to mint for msg.value

        totalSold = totalSold + payout;

        FNFT.safeTransferFrom( address(this), msg.sender, payout );        

        emit Deposit(msg.sender, msg.value, payout);
    }

    // @notice it checks a users ETH allocation remaining
    function getUserRemainingAllocation(address _user) external view returns ( uint256 ) {
        UserInfo memory user = userInfo[_user];
        return cap - user.amount;
    }

    //Managerial

    function adminWithdrawProfit() external onlyOwner {
        if (!ended) revert SaleActive();
        
        totalRaised = 0;

        _safeTransferETH(msg.sender, totalRaised);

        emit AdminProfitWithdrawal(address(FNFT), totalRaised);        
    }

    function adminWithdrawFNFT() external onlyOwner {
        if (!ended) revert SaleActive();
        //TODO: Add redemption check

        uint fNFTBalance = IfNFT( address(FNFT) ).balanceOf(address(this));
        FNFT.safeTransfer( address(msg.sender), fNFTBalance);

        emit AdminFNFTWithdrawal(address(FNFT), fNFTBalance);
    }

    // @notice approve fNFT usage by other contracts, such as CreatorFNFTUtility
    function approve(address recipient) public onlyOwner {
        FNFT.approve(recipient, 1e18);
    }

    //Helper functions

    function _safeTransferETH(address to, uint value) private {
        (bool success,) = to.call{value:value}(new bytes(0));
        if (!success) revert TxFailed();        
    }
}