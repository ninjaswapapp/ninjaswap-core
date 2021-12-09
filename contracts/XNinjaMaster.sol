// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./libs/IBEP20.sol";
import "./libs/SafeBEP20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./XNinjaSwap.sol";
// XNinjaMaster is the master of XNINJA. He can make XNINJA and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once XNINJA is sufficiently
// distributed and the community can show to govern itself.
//
contract XNinjaMaster is Ownable, ReentrancyGuard , Pausable {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;         // How many LP tokens the user has provided.
        uint256 rewardDebt;     // Reward debt. See explanation below.
        uint256 depositTime; // time of deposit LP token
        //
        // We do some fancy math here. Basically, any point in time, the amount of XNINJAs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accXNINJAPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accXNINJAPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IBEP20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. XNINJAs to distribute per block.
        uint256 lastRewardBlock;  // Last block number that XNINJAs distribution occurs.
        uint256 accXNINJAPerShare;   // Accumulated XNINJAs per share, times 1e18. See below.
        uint256 lockPeriod; // lock period of  LP pool
    }

   // The XNINJA TOKEN!
    XNinjaSwap public XNINJA;

    // XNINJA tokens created per block.
    uint256 public xninjaPerBlock = 100000000000000; //0.0001 xninja
    // Bonus multiplier for early xninja makers.
    uint256 public constant BONUS_MULTIPLIER = 1;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when XNINJA mining starts.
    uint256 public startBlock;
    // The block number when XNINJA mining ends.
    uint256 public endBlock;
    // The number of block generated for a day
    uint256 public blocksPerDay = 28800;


    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event Harvest(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event UpdateEmissionRate(address indexed user, uint256 xninjaPerBlock);


    constructor(
        XNinjaSwap _xninja
    ) public {
        XNINJA = _xninja;
        startBlock = block.number;
        endBlock = startBlock.add(blocksPerDay.mul(365).mul(4)); // Farm runs for about 4 year.

    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    mapping(IBEP20 => bool) public poolExistence;
    modifier nonDuplicated(IBEP20 _lpToken) {
        require(poolExistence[_lpToken] == false, "nonDuplicated: duplicated");
        _;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    function add(uint256 _allocPoint, IBEP20 _lpToken,uint256 _lockPeriod, bool _withUpdate) public onlyOwner nonDuplicated(_lpToken){
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolExistence[_lpToken] = true;
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accXNINJAPerShare: 0,
            lockPeriod : _lockPeriod
            
        }));
    }

    // Update the given pool's XNINJA allocation point and lockPeriod. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, uint256 _lockPeriod, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].lockPeriod = _lockPeriod;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
          if (block.number > endBlock) {
            return 0;
        } else {
             return _to.sub(_from).mul(BONUS_MULTIPLIER);
        }
    }

    // View function to see pending XNINJAs on frontend.
    function pendingXNINJA(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accXNINJAPerShare = pool.accXNINJAPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 xninjaReward = multiplier.mul(xninjaPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accXNINJAPerShare = accXNINJAPerShare.add(xninjaReward.mul(1e18).div(lpSupply));
        }
        return user.amount.mul(accXNINJAPerShare).div(1e18).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0 || pool.allocPoint == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 xninjaReward = multiplier.mul(xninjaPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        XNINJA.mint(address(this), xninjaReward);
        pool.accXNINJAPerShare = pool.accXNINJAPerShare.add(xninjaReward.mul(1e18).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for XNINJA allocation.
    function deposit(uint256 _pid, uint256 _amount) public whenNotPaused nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accXNINJAPerShare).div(1e18).sub(user.rewardDebt);
            if(pending > 0) {
                safeXNINJATransfer(msg.sender, pending);
                emit Harvest(msg.sender, pending);

            }
        }
        if(_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.depositTime = now;
        user.rewardDebt = user.amount.mul(pool.accXNINJAPerShare).div(1e18);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        require(now >= user.depositTime + pool.lockPeriod, "withdraw: lock time not reach");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accXNINJAPerShare).div(1e18).sub(user.rewardDebt);
        if(pending > 0) {
            safeXNINJATransfer(msg.sender, pending);
            emit Harvest(msg.sender, pending);

        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accXNINJAPerShare).div(1e18);
        emit Withdraw(msg.sender, _pid, _amount);
    }

      // harvest reward from MasterChef.
    function harvestFor(uint256 _pid) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accXNINJAPerShare).div(1e18).sub(user.rewardDebt);
            if (pending > 0) {
                safeXNINJATransfer(msg.sender, pending);
                user.rewardDebt = user.amount.mul(pool.accXNINJAPerShare).div(1e18);
                emit Harvest(msg.sender, pending);
            }
        }
    }
    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.lpToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    // Safe xninja transfer function, just in case if rounding error causes pool to not have enough XNINJAs.
    function safeXNINJATransfer(address _to, uint256 _amount) internal {
        uint256 xninjaBal = XNINJA.balanceOf(address(this));
        bool transferSuccess = false;
        if (_amount > xninjaBal) {
            transferSuccess = XNINJA.transfer(_to, xninjaBal);
        } else {
            transferSuccess = XNINJA.transfer(_to, _amount);
        }
        require(transferSuccess, "safeXNINJATransfer: Transfer failed");
    }

    function updateEmissionRate(uint256 _xninjaPerBlock) public onlyOwner {
        massUpdatePools();
        xninjaPerBlock = _xninjaPerBlock;
        emit UpdateEmissionRate(msg.sender, _xninjaPerBlock);
    }
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}