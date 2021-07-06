// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;
import "./libs/BEP20.sol";
import "./libs/SafeBEP20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IStdReference {
    /// A structure returned whenever someone requests for standard reference data.
    struct ReferenceData {
        uint256 rate; // base/quote exchange rate, multiplied by 1e18.
        uint256 lastUpdatedBase; // UNIX epoch of the last time when base price gets updated.
        uint256 lastUpdatedQuote; // UNIX epoch of the last time when quote price gets updated.
    }

    /// Returns the price data for the given base/quote pair. Revert if not available.
    function getReferenceData(string memory _base, string memory _quote)
        external
        view
        returns (ReferenceData memory);
}

contract NinjaStarter is ReentrancyGuard, Ownable, Pausable {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;
    IStdReference internal ref;
    uint256 testBNBprice = 287857100000000000000;
    //offering token
    IBEP20 public offeringToken;

    // BUSD Token
    IBEP20 public BUSD;

    // total amount of offeringToken that will offer
    uint256 public offeringAmount = 3000 * 1e18;

    // limit on each address on buy
    uint256 public buyCap = 0;

    // offering token price in BUSD
    uint256 public buyPrice = 4 * 1e18;

    // Time when the token sale closes
    bool public isEnded = false;

    // limit on each address on buy
    uint256 public totalSold = 0;

    // Keeps track of BNB deposited
    uint256 public totalCollectedBNB = 0;

    // Keeps track of BUSD deposited
    uint256 public totalCollectedBUSD = 0;

    //offering token owner address
    address payable public tokenOwner;

    //ninjaswap fee collector address
    address payable public feeAddress;

    //Total sale participants
    uint256 public totalSaleParticipants;

    //ninjaswap will charge this fee 1.5% max 10000 means 100%
    uint16 public fee = 150;

    //Amount each user deposited BUSD
    mapping(address => uint256) public busdDeposits;

    //Amount each user deposited BNB
    mapping(address => uint256) public bnbDeposits;

    //Amount of offering token bought each user
    mapping(address => uint256) public purchases;

     event test(address user, uint256 amount, uint256 deposit);
    constructor(
        IBEP20 _offeringToken,
        IBEP20 _busd,
        address payable _tokenOwner,
        address payable _feeAddress
    ) public {
        offeringToken = _offeringToken;
        BUSD = _busd;
        tokenOwner = _tokenOwner;
        feeAddress = _feeAddress;
        ref = IStdReference(0xDA7a001b254CD22e46d3eAB04d937489c93174C3);
    }

    receive() external payable {
        if (isEnded) {
            revert();
        }
        buywithBNB(msg.sender);
    }

    function buywithBNB(address _beneficiary)
        public
        payable
        whenNotPaused
    {
        uint256 bnbAmount = msg.value;
        require(bnbAmount > 0, "Please send some more BNB");
        require(_preValidation(), "offering already finalized");
        uint256 tokensToBePurchased = _getTokenAmount(bnbAmount);
        tokensToBePurchased = _verifyAmount(tokensToBePurchased);
        require(tokensToBePurchased > 0, "You've reached your limit of purchases");
        uint256 cost = tokensToBePurchased.mul(buyPrice).div(testBNBprice);
        if (bnbAmount > cost) {
            (bool sent, ) = payable(msg.sender).call{value: msg.value - (cost)}("");
            require(sent);
             bnbAmount = cost;
        }
        // Update total sale participants
        if (bnbDeposits[_beneficiary] == 0) {
            totalSaleParticipants = totalSaleParticipants.add(1);
        }
        totalCollectedBNB = totalCollectedBNB.add(bnbAmount);
         emit test(_beneficiary, tokensToBePurchased, bnbAmount);
        offeringToken.safeTransfer(address(msg.sender), tokensToBePurchased);
        totalSold = totalSold.add(tokensToBePurchased);
        bnbDeposits[msg.sender] = bnbDeposits[msg.sender].add(bnbAmount);
        purchases[msg.sender] = purchases[msg.sender].add(tokensToBePurchased);
    }

    function buyWithBusd(uint256 _amountBusd) public whenNotPaused {
        require(_amountBusd > 0, "Please Send some more BUSD");
        require(_preValidation(), "offering already finalized");
        uint256 tokensToBePurchased = _amountBusd.div(buyPrice);
        tokensToBePurchased = _verifyAmount(tokensToBePurchased);
        require(tokensToBePurchased > 0, "You've reached your limit of purchases");
        uint256 totalBusd = tokensToBePurchased.mul(buyPrice);
        BUSD.safeTransferFrom(address(msg.sender), address(this), totalBusd);
        // Update total sale participants
        if (busdDeposits[msg.sender] == 0) {
            totalSaleParticipants = totalSaleParticipants.add(1);
        }
        offeringToken.safeTransfer(address(msg.sender), tokensToBePurchased);
        totalSold = totalSold.add(tokensToBePurchased);
        totalCollectedBUSD = totalCollectedBUSD.add(totalBusd);
        busdDeposits[msg.sender] = busdDeposits[msg.sender].add(totalBusd);
        purchases[msg.sender] = purchases[msg.sender].add(tokensToBePurchased);
    }

    function getEstimatedTokensBuyWithBNB(uint256 _bnbAmount)
        public
        view
        returns (uint256)
    {
        return _bnbAmount.mul(testBNBprice).div(buyPrice);
    }

    function _preValidation() internal view returns (bool) {
        // offering should not endeded
        bool a = !isEnded;

        // should have available offering tokens
        bool b = offeringToken.balanceOf(address(this)) > 0;

        bool c = msg.sender != address(0);
        return a && b && c;
    }

    function endOffering() public onlyOwner {
        require(!isEnded, "offering already finalized");
        uint256 balance = offeringToken.balanceOf(address(this));
        if (balance > 0) {
            offeringToken.safeTransfer(address(0), balance);
        }
        isEnded = true;
    }

    function _getTokenAmount(uint256 _bnbAmount)
        internal
        view
        returns (uint256)
    {
        return _bnbAmount.mul(testBNBprice).div(buyPrice);
    }

    function _verifyAmount(uint256 _tokensAmount)
        internal
        view
        returns (uint256)
    {
        uint256 canBeBought = _tokensAmount;
        if (buyCap > 0 && canBeBought.add(purchases[msg.sender]) > buyCap) {
            canBeBought = buyCap.sub(purchases[msg.sender]);
        }
        if (canBeBought > offeringToken.balanceOf(address(this))) {
            canBeBought = offeringToken.balanceOf(address(this));
        }
        return canBeBought;
    }

    function setOfferingAmount(uint256 _offerAmount) public onlyOwner {
        offeringAmount = _offerAmount;
    }

    function getLatestBNBPrice() public view returns (uint256) {
        IStdReference.ReferenceData memory data = ref.getReferenceData(
            "BNB",
            "USD"
        );
        return data.rate;
    }

    function setBuyCap(uint256 _buyCap) public onlyOwner {
        buyCap = _buyCap;
    }

    function setFee(uint16 _fee) public onlyOwner {
        require(_fee <= 10000, "invalid fee basis points");
        fee = _fee;
    }

    function setPrice(uint256 _buyPrice) public onlyOwner {
        buyPrice = _buyPrice;
    }

    function finalWithdraw() public onlyOwner {
        uint256 bnbBalance = address(this).balance;
        uint256 busdBalance = BUSD.balanceOf(address(this));
        if (busdBalance > 0) {
            uint256 busdFee = busdBalance.mul(fee).div(10000);
            busdBalance = busdBalance.sub(busdFee);
            BUSD.safeTransfer(feeAddress, busdFee);
            BUSD.safeTransfer(tokenOwner, busdBalance);
        }
        if (bnbBalance > 0) {
            uint256 bnbFee = busdBalance.mul(fee).div(10000);
            bnbBalance = bnbBalance.sub(bnbFee);
            feeAddress.transfer(bnbFee);
            tokenOwner.transfer(bnbBalance);
        }
    }

    //recover stuck tokens in case someone transfer fund in accident
    function recoverStuckTokens(IBEP20 _token, uint256 _amount)
        public
        onlyOwner
    {
        IBEP20(_token).safeTransfer(msg.sender, _amount);
    }
}
