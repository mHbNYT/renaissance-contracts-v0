// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

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

    mapping(address => UserInfo) public userInfo;
    mapping(address => bool) public whitelisted; // True if user is whitelisted

    event Deposit(address indexed who, uint256 amount, uint256 payout);
    event Withdraw(address token, address indexed who, uint256 amount);
    event Mint(address token, address indexed who, uint256 amount);
    event SaleStarted(uint256 block);
    event SaleEnded(uint256 block);

    constructor(
        address _fNFT,
        uint256 _amountForSale,
        uint256 _price,
        uint256 _cap,
        bool _allowWhitelisting
    ) {
        require( _fNFT != address(0), "Ifo: _fNFT 0");
        FNFT = IERC20(_fNFT);
        require( amountForSale != 0, "Ifo: amountForSale 0");
        amountForSale = _amountForSale;
        require( _price != 0, "Ifo: price 0" );
        price = _price;
        require( _cap != 0, "Ifo: cap 0" );
        cap = _cap;

        allowWhitelisting = _allowWhitelisting;
    }

    //* @notice modifer to check if contract is paused
    modifier whitelistingAllowed() {
        require(allowWhitelisting == true, "addWhitelist: false");
        _;
    }

    //* @notice modifer to check if contract is paused
    modifier checkIfPaused() {
        require(contractPaused == false, "contract is paused");
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
        require(allowWhitelisting == true, "addWhitelist: false");
        whitelisted[_address] = true;
    }
    
    /**
     *  @notice adds multiple whitelist to the sale
     *  @param _addresses: dynamic array of addresses to whitelist
     */
    function addMultipleWhitelists(address[] calldata _addresses) external onlyOwner whitelistingAllowed {
        require(_addresses.length <= 333,"too many addresses");
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
        require(!started, "Sale has already started");
        started = true;
        emit SaleStarted(block.number);
    }

    // @notice Ends the sale
    function end() external onlyOwner {
        require(started, "Sale has not started");
        require(!ended, "Sale has already ended");
        ended = true;
        emit SaleEnded(block.number);
    }

    // @notice lets owner pause contract
    function togglePause() external onlyOwner returns (bool){
        contractPaused = !contractPaused;
        return contractPaused;
    }

    /**
     *  @notice transfer ERC20 token to DAO multisig
     *  @param _token: token address to withdraw
     *  @param _amount: amount of token to withdraw
     */
    function adminWithdraw(address _token, uint256 _amount) external onlyOwner {
        IERC20( _token ).safeTransfer( address(msg.sender), _amount );
        emit AdminWithdrawal(_token, _amount);
    }

    /**
     *  @notice it deposits FRAX for the sale
     *  @param _amount: amount of FRAX to deposit to sale (18 decimals)
     */
    function deposit() external payable checkIfPaused {
        require(started, "deposit: Sale not started");
        require(!ended, "deposit: Sale ended");        
        require(cap >= user.amount.add(msg.value), "deposit: over limit");
        if (allowWhitelisting == true) {
            require(whitelisted[msg.sender] == true, "deposit: not whitelisted");
        }

        UserInfo storage user = userInfo[msg.sender];

        user.amount = user.amount.add(msg.value);
        totalRaised = totalRaised.add(msg.value);

        uint256 payout = msg.value.mul(1e18).div(price).div(1e18); // fNFT to mint for msg.value

        totalSold = totalSold.add(payout);

        FNFT.safeTransferFrom( address(this), msg.sender, payout );        

        emit Deposit(msg.sender, msg.value, payout);
    }


}