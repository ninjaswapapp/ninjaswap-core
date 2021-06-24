// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import "./libs/BEP20.sol";
import "./libs/SafeBEP20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

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

    //offering token
    IBEP20 public offeringToken;
    // BUSD Token
    IBEP20 public BUSD;
    // total amount of offeringToken that will offer
    uint256 public offeringAmount = 4000*1e18;
    // limit on each address on buy
    uint256 public buyCap = 0;
    // offering token price in BUSD
    uint256 public price = 4*1e18;
    bool public isEnded = false;
    // limit on each address on buy
    uint256 public totalsoldTokens = 0;
    uint256 public totalBNBRaised = 0;
    uint256 public totalBUSDRaised = 0;
    address public tokenOwner;
    mapping(address => uint256) public busdDeposits;
    mapping(address => uint256) public bnbDeposits;
    mapping(address => uint256) public purchases;

    constructor(
            IBEP20 _offeringToken,
            IBEP20 _busd,
            address _tokenOwner
    ) public {
        offeringToken = _offeringToken;
        BUSD = _busd;
        tokenOwner = _tokenOwner;
        ref = IStdReference(0xDA7a001b254CD22e46d3eAB04d937489c93174C3);
    }

    receive() external payable {
        if (isEnded) {
            revert(); //Block Incoming BNB Deposits if Crowdsale has ended
        }
        buywithBNB(msg.sender);
    }

    function buywithBNB(address _beneficiary) public payable {
        uint256 bnbAmount = msg.value;
        require(bnbAmount > 0, "Please Send some BNB");
        if (isEnded) {
            revert();
        }

        _preValidatePurchase(_beneficiary);
        uint256 tokensToBePurchased = _getTokenAmount(bnbAmount);
        if (tokensToBePurchased > offeringToken.balanceOf(address(this)) {
            revert(); //Block Incoming BNB Deposits if tokens to be purchased, exceeds remaining tokens for sale in the current stage
        }
        offeringToken.safeTransfer(address(msg.sender), tokensToBePurchased);
        totalsoldTokens = totalsoldTokens.add(tokensToBePurchased);
        bnbDeposits[msg.sender] = bnbDeposits[msg.sender].add(_amountBusd);
        purchases[msg.sender] = purchases[msg.sender].add(tokensToBePurchased);
    }
     function buyWithBusd(
        uint256 _amountBusd
    ) public whenNotPaused {
        require(_amountBusd >= price, "Please Send some more BUSD");
        BUSD.safeTransferFrom(address(msg.sender), address(this), _amountBusd);
        uint256 tokensToBePurchased = _amountBusd.div(price);
        offeringToken.safeTransfer(address(msg.sender), tokensToBePurchased);
        totalsoldTokens = totalsoldTokens.add(tokensToBePurchased);
        busdDeposits[msg.sender] = busdDeposits[[msg.sender].add(_amountBusd);
        purchases[msg.sender] = purchases[[msg.sender].add(tokensToBePurchased);
        emit Minted(msg.sender, _estimate, _deposit);
        
    }
    function endCrowdsale() public onlyOwner {
          require(!isEnded,"Crowdsale already finalized");   
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
        return _bnbAmount.mul(getLatestBNBPrice()).div(price);
    }

    function setOfferingAmount(uint256 _offerAmount) public onlyOwner {
        offeringAmount = _offerAmount;
    }

    function getLatestBNBPrice() public view returns (uint256) {
        IStdReference.ReferenceData memory data =
            ref.getReferenceData("BNB", "USD");
        return data.rate;
    }

    function _preValidatePurchase(address _beneficiary) internal pure {
        require(_beneficiary != address(0));
    }

    function setBuyCap(uint256 _buyCap) public onlyOwner {
        buyCap = _buyCap;
    }

    function setPrice(uint256 _price) public onlyOwner {
        price = _price;
    }

    function burn() public onlyOwner {
        uint256 balance = offeringToken.balanceOf(address(this));
        if (balance > 0) {
            offeringToken.safeTransfer(address(0), balance);
        }
    }

    function finalWithdraw()
        public
        onlyOwner
    {
        uint256 bnbBalance = address(this).balance;
         uint256 busdBalance = BUSD.balanceOf(address(this))
        if (busdBalance > 0) {
            offeringToken.safeTransfer(address(msg.sender), busdBalance);
        }
        if (bnbBalance > 0) {
            address payable dev = payable(tokenOwner());
            dev.transfer(bnbBalance);
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
