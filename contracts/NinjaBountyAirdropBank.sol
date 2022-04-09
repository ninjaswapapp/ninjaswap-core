// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NinjaBountyAirdropBank  is Ownable , Pausable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event RewardClaimed(address user, uint256 roundId, uint256 reward, uint256 date);

    uint256 public currentRoundId = 0;
    address public authenticator;

    struct Round {
        uint256 roundId; // round id
        string name; // campaign name 
        IERC20 token; //reward token
        uint256 TotalReward; // total tokens for round
        uint256 TotalRewardClaimed; // total users rewards claimed 
    }
     // all rounds
    Round[] public rounds;
   
    mapping(uint256 =>mapping(address => bool)) public processedClaim;

    constructor(
        address _authenticator,
        address _token,
        uint256 _totalReward

    ) public {
        authenticator = _authenticator;
        Round storage r = rounds.push();
        r.roundId= currentRoundId;
        r.name= "NinjaSwap Round # 2";
        r.token= IERC20(_token);
        r.TotalReward = _totalReward;
        r.TotalRewardClaimed = 0;
    }

    function addNewRound(uint256 _totalReward , string memory _name , address _token) public onlyOwner {
        currentRoundId = currentRoundId.add(1);
        Round storage r = rounds.push();
        r.roundId= currentRoundId;
        r.name= _name;
        r.token= IERC20(_token);
        r.TotalReward = _totalReward;
        r.TotalRewardClaimed = 0;
    }
    function updateAuthenticator(address _authenticator) external virtual onlyOwner {
        authenticator = _authenticator;
    }
    
    function pauseClaim() public onlyOwner {
        _pause();
    }

    function unpauseClaim() public onlyOwner {
        _unpause();
    }
    
    function recoverStuckTokens(IERC20 _token, uint256 _amount , address _to) public onlyOwner {
        IERC20(_token).safeTransfer(_to, _amount);
    }
    function _claimTokens(
        address recipient,
        uint256 amount,
        uint256 _roundId,
        bytes calldata signature
    ) internal {
        bytes32 message = prefixed(keccak256(abi.encodePacked(recipient, amount)));
        require(recoverSigner(message, signature) == authenticator, "wrong signature");
        require(processedClaim[_roundId][recipient] == false, "reward already processed");
        processedClaim[_roundId][recipient] = true;
        Round storage r =  rounds[_roundId];
        r.TotalRewardClaimed = r.TotalRewardClaimed.add(amount);
        IERC20 Token = r.token;
        Token.safeTransfer(address(recipient), amount);
        emit RewardClaimed(recipient, _roundId, amount, block.timestamp);
    }

    function claimReward(uint256 amount, uint256 _roundId, bytes calldata signature)
        external
        virtual
        whenNotPaused
        nonReentrant
    {
        _claimTokens(msg.sender, amount, _roundId, signature);
    }

    function prefixed(bytes32 hash) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
            );
    }

    function recoverSigner(bytes32 message, bytes memory sig)
        internal
        pure
        returns (address)
    {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = splitSignature(sig);

        return ecrecover(message, v, r, s);
    }

    function splitSignature(bytes memory sig)
        internal
        pure
        returns (
            uint8,
            bytes32,
            bytes32
        )
    {
        require(sig.length == 65);

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }
        // Golang compatibility
        if (v == 0 || v == 1) {
            v += 27;
        }
        return (v, r, s);
    }
    function getRoundById(uint256 _roundId)
        public
        view
        returns (
            uint256,
            string memory,
            address,
            uint256,
            uint256
        )
    {
           return (
            rounds[_roundId].roundId,
            rounds[_roundId].name,
            address(rounds[_roundId].token),
            rounds[_roundId].TotalReward,
            rounds[_roundId].TotalRewardClaimed
        );
    }
}