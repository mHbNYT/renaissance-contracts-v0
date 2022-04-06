// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "./IFOSettings.sol";
import "./interfaces/IFNFT.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract IFO is Initializable {
    using SafeERC20 for IERC20;

    struct UserInfo {
        uint256 amount; // Amount ETH deposited by user
        uint256 debt; // total fNFT claimed thus fNFT debt
    }

    enum FNFTState {
        inactive,
        presale,
        live,
        ended,
        redeemed
    }

    address public curator;
    address public settings;

    IERC20 public FNFT; // fNFT the ifo contract sells
    IERC20 public ETH; // for user deposits
    uint256 public amountForSale; // amount of fNFT for sale
    uint256 public price; // initial price per fNFT
    uint256 public cap; // cap per user
    uint256 public totalRaised; // total ETH raised by sale
    uint256 public totalSold; // total fNFT sold by sale

    uint256 public duration; // ifo duration
    uint256 public startBlock; // block started
    uint256 public pauseBlock; // block paused

    bool public allowWhitelisting; // whether the ifo operates through WL
    bool public started; // true when sale is started
    bool public ended; // true when sale is ended
    bool public paused; // circuit breaker

    uint256 public liquidity = 0; //liquidity deployed by the creator

    mapping(address => UserInfo) public userInfo;
    mapping(address => bool) public whitelisted; // True if user is whitelisted

    event Deposit(address indexed _who, uint256 _amount, uint256 _payout);
    event SaleStarted(uint256 _block);
    event SaleEnded(uint256 _block);
    event PauseTriggered(bool _paused, uint256 _block);
    event AdminProfitWithdrawal(address _FNFT, uint256 _amount);
    event AdminETHWithdrawal(address _eth, uint256 _amount);
    event AdminFNFTWithdrawal(address _FNFT, uint256 _amount);    

    error NotOwner();
    error NotCurator();
    error InvalidAddress();
    error NotEnoughSupply();
    error InvalidAmountForSale();
    error InvalidPrice();
    error InvalidCap();
    error InvalidDuration();
    error InvalidReservePrice(uint256 proposedPrice);
    error WhitelistingDisallowed();
    error ContractPaused();
    error TooManyWhitelists();
    error SaleAlreadyStarted();
    error SaleUnstarted();
    error SaleAlreadyEnded();
    error DeadlineActive();
    error SaleActive();
    error TxFailed();
    error NotWhitelisted();
    error OverLimit();
    error NoLiquidityProvided();
    error FNFTLocked();

    constructor(address _settings) {
        settings = _settings;
    }
    
    function initialize(
        //original owner
        address _curator,
        //FNFT address
        address _FNFT,
        //Amount of FNFT for sale in IFO
        uint256 _amountForSale,
        //Price per FNFT in IFO
        uint256 _price,
        //Maximum an account can buy
        uint256 _cap,
        //Duration of IFO. Max duration set by DAO if _duration == 0
        uint256 _duration,
        //If IFO should be governed by whitelists
        bool _allowWhitelisting
    ) external initializer {
        // set storage variables
        if (_FNFT == address(0)) revert InvalidAddress();
        FNFT = IERC20(_FNFT);
        IFNFT fnft = IFNFT(address(FNFT));
        uint256 fractionalizerSupply = fnft.balanceOf(_curator);
        uint256 totalSupply = fnft.totalSupply();
        // make sure curator holds 100% of the FNFT before IFO (May change if DAO takes fee on fractionalize)
        if (fractionalizerSupply < totalSupply) revert NotEnoughSupply();
        // make sure amount for sale is not bigger than the supply if FNFT
        if (
            _amountForSale == 0 || _amountForSale > fractionalizerSupply
            // _amountForSale % _cap != 0
        ) revert InvalidAmountForSale();
        if (_price == 0) revert InvalidPrice();
        if (_cap == 0 || _cap > totalSupply) revert InvalidCap();
        // expect ifo duration to be between minimum and maximum durations set by the DAO
        if (_duration < IIFOSettings(settings).minimumDuration() || _duration > IIFOSettings(settings).maximumDuration()) revert InvalidDuration();
        // reject if MC of IFO greater than reserve price set by curator. Protects the initial investors
        //if the requested price of the tokens here is greater than the implied value of each token from the initial reserve, revert
        if ((_price * totalSupply) / 1e18 > fnft.initialReserve()) revert InvalidReservePrice(_price);

        curator = _curator;
        amountForSale = _amountForSale;
        price = _price;
        cap = _cap;
        allowWhitelisting = _allowWhitelisting;
        duration = _duration;        
    }

    modifier onlyCurator() {
        if (msg.sender != curator) revert NotCurator();
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != Ownable(settings).owner()) revert NotOwner();
        _;
    }

    /// @notice checks if whitelist period is over and ends whitelist
    modifier checkDeadline() {
        if (block.number > startBlock + duration && duration != 0) {
            end();
        }
        _;
    }
    
    /// @notice modifer to check if contract is paused
    modifier checkPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    /// @notice modifer to check if contract accepts whitelists
    modifier whitelistingAllowed() {
        if (!allowWhitelisting) revert WhitelistingDisallowed();
        _;
    }

    /**
     *  @notice adds a single whitelist to the sale
     *  @param _address: address to whitelist
     */
    function addWhitelist(address _address) external onlyCurator whitelistingAllowed {
        whitelisted[_address] = true;
    }

    /**
     *  @notice adds multiple whitelist to the sale
     *  @param _addresses: dynamic array of addresses to whitelist
     */
    function addMultipleWhitelists(address[] calldata _addresses) external onlyCurator whitelistingAllowed {
        if (_addresses.length > 333) revert TooManyWhitelists();
        for (uint256 i = 0; i < _addresses.length; i++) {
            whitelisted[_addresses[i]] = true;
        }
    }

    /**
     *  @notice removes a single whitelist from the sale
     *  @param _address: address to remove from whitelist
     */
    function removeWhitelist(address _address) external onlyCurator whitelistingAllowed {
        whitelisted[_address] = false;
    }

    /// @notice Starts the sale and checks if all FNFT is in IFO
    function start() external onlyCurator {
        if (started) revert SaleAlreadyStarted();
        if (ended) revert SaleAlreadyEnded();
        if (FNFT.balanceOf(address(this)) < FNFT.totalSupply()) revert NotEnoughSupply();

        startBlock = block.number;

        started = true;
        emit SaleStarted(block.number);
    }

    /// @notice lets owner pause contract. Pushes back the IFO end date
    function togglePause() external onlyCurator returns (bool) {
        if (!started) revert SaleUnstarted();
        if (ended) revert SaleAlreadyEnded();

        if (paused) {
            duration += block.number - pauseBlock;
            paused = false;
        } else {
            pauseBlock = block.number;
            paused = true;
        }
        emit PauseTriggered(paused, block.number);
        return paused;
    }

    /// @notice Ends the sale
    function end() public onlyCurator checkPaused {
        if (!started) revert SaleUnstarted();
        if (
            block.number < startBlock + duration || // If not past duration
            IIFOSettings(settings).minimumDuration() > block.number - startBlock // If tries to end before minimum duration
        ) revert DeadlineActive();
        if (ended) revert SaleAlreadyEnded();

        ended = true;
        emit SaleEnded(block.number);
    }
    
    ///@notice it deposits ETH for the sale
    function deposit() external payable checkPaused checkDeadline {
        if (!started) revert SaleUnstarted();
        if (ended) revert SaleAlreadyEnded();
        if (allowWhitelisting == true) {
            if (!whitelisted[msg.sender]) revert NotWhitelisted();
        }

        UserInfo storage user = userInfo[msg.sender];
        if (user.amount + msg.value > cap) revert OverLimit();

        user.amount = user.amount + msg.value;
        totalRaised = totalRaised + msg.value;

        uint256 payout = (msg.value * 1e18) / price; // fNFT to mint for msg.value

        totalSold = totalSold + payout;

        FNFT.safeTransferFrom(address(this), msg.sender, payout);

        emit Deposit(msg.sender, msg.value, payout);
    }

    /** @notice it checks a users ETH allocation remaining
    *   @param _user: user's remaining allocation based on cap  
    */
    function getUserRemainingAllocation(address _user) external view returns (uint256) {
        UserInfo memory user = userInfo[_user];
        return cap - user.amount;
    }

    //Managerial

    /** @notice after redeploying settings contract
        @param _settings: new settings contract
    */
    function setSettings(address _settings) external onlyOwner {
        settings = _settings;
    }

    /** @notice If wrong FNFT
    *   @param _address: address of FNFT
    */
    function updatefNFTAddress(address _address) external onlyOwner {
        FNFT = IERC20(_address);
    }

    /// @notice withdraws ETH from sale only after IFO over
    function adminWithdrawProfit() external checkDeadline onlyCurator {
        if (!ended) revert SaleActive();

        totalRaised = 0;

        _safeTransferETH(msg.sender, totalRaised);

        emit AdminProfitWithdrawal(address(FNFT), totalRaised);
    }

    /// @notice withdraws FNFT from sale only after IFO. Can only withdraw after NFT redemption if IFOLock enabled
    function adminWithdrawFNFT() external checkDeadline onlyCurator {
        if (!ended) revert SaleActive();
        if (IIFOSettings(settings).creatorIFOLock() && IFNFT(address(FNFT)).auctionState() != uint256(FNFTState.redeemed))
            revert FNFTLocked();

        uint256 fNFTBalance = IFNFT(address(FNFT)).balanceOf(address(this));
        FNFT.safeTransfer(address(msg.sender), fNFTBalance);

        emit AdminFNFTWithdrawal(address(FNFT), fNFTBalance);
    }

    /// @notice approve fNFT usage by creator utility contract, to deploy LP pool or stake if IFOLock enabled
    function approve() public onlyCurator {
        if (!ended) revert SaleActive();        

        FNFT.safeApprove(IIFOSettings(settings).creatorUtilityContract(), 1e18);
    }

    //Helper functions

    /** @notice transfer ETH using call
    *   @param _to: address to transfer ETH to
    *   @param _value: amount of ETH to transfer
    */
    function _safeTransferETH(address _to, uint256 _value) private {
        (bool success, ) = _to.call{value: _value}(new bytes(0));
        if (!success) revert TxFailed();
    }
}
