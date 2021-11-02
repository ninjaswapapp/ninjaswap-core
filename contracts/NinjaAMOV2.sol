// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./NinjaToken.sol";

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

contract NinjaAMOV2 is ReentrancyGuard, Ownable, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    IStdReference internal ref;

    //AMO token
    NinjaToken public ninjaToken;

    // BUSD Token
    IERC20 public BUSD;

    // AMO token price in 2.5 BUSD
    uint256 public mintPrice = 25 * 1e17;

    // Max AMO mintable tokens 2.8 M
    uint256 public maxMintable = 2800000 * 1e18;

    // AMOv2 stop permanently
    bool public isEnded = false;

    // total tokens minted by amoV2
    uint256 public TotalAMOV2Mints = 0;

    // Keeps track of BNB deposited
    uint256 public totalCollectedBNB = 0;

    // Keeps track of BUSD deposited
    uint256 public totalCollectedBUSD = 0;

    //development funds Treasury
    address payable public developmentTreasury;

     //marketing funds Treasury
    address payable public marketersTreasury;

    //ninjaswap fee collector address
    address payable public feeAddress;

    //Total sale participants
    uint256 public totalSaleParticipants;

    //1.5% fee will be charged from all funds to buyback and burn ninja and  xninja
    uint16 public fee = 150;

    //Amount each user deposited BUSD
    mapping(address => uint256) public busdDeposits;

    //Amount each user deposited BNB
    mapping(address => uint256) public bnbDeposits;

    //Amount of minted tokens by each user
    mapping(address => uint256) public Minted;

    event Mint(address user, uint256 amount);
    
    constructor(
        NinjaToken _ninjaToken,
        IERC20 _busd,
        address payable _developmentTreasury,
        address payable _marketersTreasury,
        address payable _feeAddress
    ) public {
        ninjaToken = _ninjaToken;
        BUSD = _busd;
        developmentTreasury = _developmentTreasury;
        marketersTreasury = _marketersTreasury;
        feeAddress = _feeAddress;
        ref = IStdReference(0xDA7a001b254CD22e46d3eAB04d937489c93174C3);
    }

    receive() external payable {
        if (isEnded) {
            revert();
        }
        mintWithBNB(msg.sender);
    }

    function mintWithBNB(address _beneficiary) public payable whenNotPaused nonReentrant
    {
        uint256 bnbAmount = msg.value;
        require(bnbAmount > 0, "Please send some more BNB");
        require(_preValidation(), "AMO already finalized");
        uint256 tokensToBeMint = _getTokenAmount(bnbAmount);
        tokensToBeMint = _checkMaxMint(tokensToBeMint);
        require(tokensToBeMint > 0, "You've reached your limit of purchases");
        uint256 cost = tokensToBeMint.mul(mintPrice).div(getLatestBNBPrice());
        if (bnbAmount > cost) {
            address payable refundAccount = payable(_beneficiary);
	        refundAccount.transfer(bnbAmount.sub(cost));
            bnbAmount = cost;
        }
        // Update total sale participants
        if (busdDeposits[msg.sender] == 0 && bnbDeposits[_beneficiary] == 0) {
            totalSaleParticipants = totalSaleParticipants.add(1);
        }
        totalCollectedBNB = totalCollectedBNB.add(bnbAmount);
        ninjaToken.mint(address(msg.sender), tokensToBeMint);
        uint256 _teamShare = tokensToBeMint.mul(15).div(100); // 0.15x 
        ninjaToken.mint(address(this), _teamShare);
        TotalAMOV2Mints = TotalAMOV2Mints.add(tokensToBeMint);
        bnbDeposits[msg.sender] = bnbDeposits[msg.sender].add(bnbAmount);
        Minted[msg.sender] = Minted[msg.sender].add(tokensToBeMint);
        emit Mint(_beneficiary, tokensToBeMint);
    }

    function mintWithBUSD(uint256 _amountBusd) public whenNotPaused nonReentrant {
        require(_amountBusd > 0, "Please Send some more BUSD");
        require(_preValidation(), "AMO already finalized");
        uint256 tokensToBeMint = _amountBusd.mul(10**18).div(mintPrice);
        tokensToBeMint = _checkMaxMint(tokensToBeMint);
        require(tokensToBeMint > 0, "You've reached your limit of purchases");
        uint256 totalBusd = tokensToBeMint.mul(mintPrice).div(10**18);
        BUSD.safeTransferFrom(address(msg.sender), address(this), totalBusd);
        // Update total sale participants
        if (busdDeposits[msg.sender] == 0 && bnbDeposits[msg.sender] == 0) {
            totalSaleParticipants = totalSaleParticipants.add(1);
        }
        ninjaToken.mint(address(msg.sender), tokensToBeMint);
        uint256 _teamShare = tokensToBeMint.mul(15).div(100); // 0.15x 
        ninjaToken.mint(address(this), _teamShare);
        TotalAMOV2Mints = TotalAMOV2Mints.add(tokensToBeMint);
        totalCollectedBUSD = totalCollectedBUSD.add(totalBusd);
        busdDeposits[msg.sender] = busdDeposits[msg.sender].add(totalBusd);
        Minted[msg.sender] = Minted[msg.sender].add(tokensToBeMint);
        emit Mint(msg.sender, tokensToBeMint);
    }

    function _checkMaxMint(uint256 _tokensAmount) internal view returns (uint256) {
        uint256 canBeMint = _tokensAmount;
        uint256 _teamShare = canBeMint.mul(15).div(100); // 0.15x 
        uint256 amoTotalminted = ninjaToken.AMOMinted();
        if (amoTotalminted.add(canBeMint.add(_teamShare)) > maxMintable) { // Only amo minted allowed 2.8 million
            canBeMint =  maxMintable.sub(amoTotalminted);
            canBeMint = canBeMint.mul(100).div(115); // 0.15x 
        }
        return canBeMint;
    }

    function getEstimatedTokensMintWithBNB(uint256 _bnbAmount) public view returns (uint256) {
        return _bnbAmount.mul(getLatestBNBPrice()).div(mintPrice);
    }
    
    function _preValidation() internal view returns (bool) {
        bool a = !isEnded;

        bool b = msg.sender != address(0);
        return a && b;
    }

    function endAMO() public onlyOwner {
        require(!isEnded, "AMO already finalized");
        isEnded = true;
    }
    function _getTokenAmount(uint256 _bnbAmount)
        internal
        view
        returns (uint256)
    {
        return _bnbAmount.mul(getLatestBNBPrice()).div(mintPrice);
    }

    function getLatestBNBPrice() public view returns (uint256) {
        IStdReference.ReferenceData memory data = ref.getReferenceData(
            "BNB",
            "USD"
        );
        return data.rate;
    }

    function setFee(uint16 _fee) public onlyOwner {
        require(_fee <= 1000, "invalid fee basis points"); // max 10%
        fee = _fee;
    }

    function setMintPrice(uint256 _mintPrice) public onlyOwner {
        mintPrice = _mintPrice;
    }

    function withdrawFunds() public onlyOwner {
        uint256 bnbBalance = address(this).balance;
        uint256 busdBalance = BUSD.balanceOf(address(this));
        if (busdBalance > 0) {
            uint256 busdFee = busdBalance.mul(fee).div(10000);
            busdBalance = busdBalance.sub(busdFee);
            // split busd balance into halves
            uint256 half      = busdBalance.div(2);
            uint256 otherHalf = busdBalance.sub(half);
            BUSD.safeTransfer(feeAddress, busdFee);
            BUSD.safeTransfer(developmentTreasury, half);
            BUSD.safeTransfer(marketersTreasury, otherHalf);
        }
          if (bnbBalance > 0) {
            uint256 bnbFee = bnbBalance.mul(fee).div(10000);
            bnbBalance = bnbBalance.sub(bnbFee);
            // split BNB balance into halves
            uint256 half      = bnbBalance.div(2);
            uint256 otherHalf = bnbBalance.sub(half);
            feeAddress.transfer(bnbFee);
            developmentTreasury.transfer(half);
            marketersTreasury.transfer(otherHalf);
        }
    
    //Withdraw team tokens with timelock
    function withdrawTeamTokens(address _to, uint256 _amount) public onlyOwner {
       ninjaToken.transferFrom(address(this), _to, _amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function updateDevelopmentTreasuryAdd(address payable _developmentTreasury) public onlyOwner {
        developmentTreasury = _developmentTreasury;
    }

    function updateMarketersTreasury(address payable _marketersTreasury) public onlyOwner {
        marketersTreasury = _marketersTreasury;
    }

    function TotalLockedTeamTokens() public view returns (uint256) {
        return ninjaToken.balanceOf(address(this));
    }
    
    function totalAMOTokens() public view returns (uint256) {
        return ninjaToken.AMOMinted();
    }
}
