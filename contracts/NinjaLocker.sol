/*
███╗░░██╗██╗███╗░░██╗░░░░░██╗░█████╗░  ░██████╗░██╗░░░░░░░██╗░█████╗░██████╗░
████╗░██║██║████╗░██║░░░░░██║██╔══██╗  ██╔════╝░██║░░██╗░░██║██╔══██╗██╔══██╗
██╔██╗██║██║██╔██╗██║░░░░░██║███████║  ╚█████╗░░╚██╗████╗██╔╝███████║██████╔╝
██║╚████║██║██║╚████║██╗░░██║██╔══██║  ░╚═══██╗░░████╔═████║░██╔══██║██╔═══╝░
██║░╚███║██║██║░╚███║╚█████╔╝██║░░██║  ██████╔╝░░╚██╔╝░╚██╔╝░██║░░██║██║░░░░░
╚═╝░░╚══╝╚═╝╚═╝░░╚══╝░╚════╝░╚═╝░░╚═╝  ╚═════╝░░░░╚═╝░░░╚═╝░░╚═╝░░╚═╝╚═╝░░░░░

Ninja Locker
https://ninjaswap.app
*/
// SPDX-License-Identifier: MIT

pragma solidity ^0.4.25;

contract Token {
    function balanceOf(address who) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function approveAndCall(
        address spender,
        uint256 tokens,
        bytes data
    ) external returns (bool success);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
}

library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a / b;
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);
        return c;
    }

    function ceil(uint256 a, uint256 m) internal pure returns (uint256) {
        uint256 c = add(a, m);
        uint256 d = sub(c, 1);
        return mul(div(d, m), m);
    }
}

/*
 *	Allows for contract ownership along with multi-address authorization
 */
contract Auth {
    address internal owner;
    mapping(address => bool) internal authorizations;

    constructor(address _owner) public {
        owner = _owner;
        authorizations[_owner] = true;
    }

    //Function modifier to require caller to be contract owner
    modifier onlyOwner() {
        require(isOwner(msg.sender), "!OWNER");
        _;
    }

    //Function modifier to require caller to be authorized
    modifier authorized() {
        require(authorizedYes(msg.sender), "!AUTHORIZED");
        _;
    }

    //Authorize address. Owner only
    function authorize(address adr) public onlyOwner {
        authorizations[adr] = true;
    }

    //Return address' authorization status
    function authorizedYes(address adr) public view returns (bool) {
        return authorizations[adr];
    }

    //Remove address' authorization. Owner only
    function authorizeOff(address adr) public onlyOwner {
        authorizations[adr] = false;
    }

    //Check if address is owner
    function isOwner(address account) public view returns (bool) {
        return account == owner;
    }

    //Transfer ownership to new address. Caller must be owner. Leaves old owner authorized
    function transferOwnership(address newOwner) public onlyOwner {
        owner = newOwner;
        authorizations[newOwner] = true;
        emit OwnershipTransferred(newOwner);
    }

    event OwnershipTransferred(address owner);
}

contract NinjaLocker is Auth {
    using SafeMath for uint256;

    /*
     * deposit vars
     */
    struct Items {
        address tokenAddress;
        address withdrawalAddress;
        uint256 tokenAmount;
        uint256 unlockTime;
        bool withdrawn;
    }

    uint256 public depositId;
    uint256[] public allDepositIds;
    mapping(address => uint256[]) public depositsByWithdrawalAddress;
    mapping(uint256 => Items) public lockedToken;
    mapping(address => mapping(address => uint256)) public walletTokenBalance;

    event LogWithdrawal(address SentToAddress, uint256 AmountTransferred);

    /**
     * Constrctor function
     */
    constructor() public Auth(msg.sender) {}

    /**
     *lock tokens
     */
    function lockTokens(
        address _tokenAddress,
        address _withdrawAddress,
        uint256 _amount,
        uint256 _unlockTime
    ) public authorized returns (uint256 _id) {
        require(_amount > 0, "token amount is Zero");
        require(
            _unlockTime < 10000000000,
            "Enter an unix timestamp in seconds, not miliseconds"
        );
        require(
            Token(_tokenAddress).approve(this, _amount),
            "Approve tokens failed"
        );
        require(
            Token(_tokenAddress).transferFrom(msg.sender, this, _amount),
            "Transfer of tokens failed"
        );
        authorizations[_withdrawAddress] = true;
        //update balance in address
        walletTokenBalance[_tokenAddress][
            _withdrawAddress
        ] = walletTokenBalance[_tokenAddress][_withdrawAddress].add(_amount);

        address _withdrawalAddress = _withdrawAddress;
        _id = ++depositId;
        lockedToken[_id].tokenAddress = _tokenAddress;
        lockedToken[_id].withdrawalAddress = _withdrawalAddress;
        lockedToken[_id].tokenAmount = _amount;
        lockedToken[_id].unlockTime = _unlockTime;
        lockedToken[_id].withdrawn = false;

        allDepositIds.push(_id);
        depositsByWithdrawalAddress[_withdrawalAddress].push(_id);
    }

    /**
     *withdraw tokens
     */
    function withdrawTokens(uint256 _id) public {
        require(
            block.timestamp >= lockedToken[_id].unlockTime,
            "Tokens are locked"
        );
        require(
            msg.sender == lockedToken[_id].withdrawalAddress,
            "Can withdraw by withdrawal Address only"
        );
        require(!lockedToken[_id].withdrawn, "Tokens already withdrawn");
        require(
            Token(lockedToken[_id].tokenAddress).transfer(
                msg.sender,
                lockedToken[_id].tokenAmount
            ),
            "Transfer of tokens failed"
        );

        lockedToken[_id].withdrawn = true;

        //update balance in address
        walletTokenBalance[lockedToken[_id].tokenAddress][
            msg.sender
        ] = walletTokenBalance[lockedToken[_id].tokenAddress][msg.sender].sub(
            lockedToken[_id].tokenAmount
        );

        //remove this id from this address
        uint256 i;
        uint256 j;
        for (
            j = 0;
            j <
            depositsByWithdrawalAddress[lockedToken[_id].withdrawalAddress]
                .length;
            j++
        ) {
            if (
                depositsByWithdrawalAddress[lockedToken[_id].withdrawalAddress][
                    j
                ] == _id
            ) {
                for (
                    i = j;
                    i <
                    depositsByWithdrawalAddress[
                        lockedToken[_id].withdrawalAddress
                    ].length -
                        1;
                    i++
                ) {
                    depositsByWithdrawalAddress[
                        lockedToken[_id].withdrawalAddress
                    ][i] = depositsByWithdrawalAddress[
                        lockedToken[_id].withdrawalAddress
                    ][i + 1];
                }
                depositsByWithdrawalAddress[lockedToken[_id].withdrawalAddress]
                    .length--;
                break;
            }
        }
        emit LogWithdrawal(msg.sender, lockedToken[_id].tokenAmount);
    }

    /*get total token balance in contract*/
    function getTotalTokenBalance(address _tokenAddress)
        public
        view
        returns (uint256)
    {
        return Token(_tokenAddress).balanceOf(this);
    }

    /*get total token balance by address*/
    function getTokenBalanceByAddress(
        address _tokenAddress,
        address _walletAddress
    ) public view returns (uint256) {
        return walletTokenBalance[_tokenAddress][_walletAddress];
    }

    /*get allDepositIds*/
    function getAllDepositIds() public view returns (uint256[]) {
        return allDepositIds;
    }

    /*get getDepositDetails*/
    function getDepositDetails(uint256 _id)
        public
        view
        returns (
            address,
            address,
            uint256,
            uint256,
            bool
        )
    {
        return (
            lockedToken[_id].tokenAddress,
            lockedToken[_id].withdrawalAddress,
            lockedToken[_id].tokenAmount,
            lockedToken[_id].unlockTime,
            lockedToken[_id].withdrawn
        );
    }

    /*get DepositsByWithdrawalAddress*/
    function getDepositsByWithdrawalAddress(address _withdrawalAddress)
        public
        view
        returns (uint256[])
    {
        return depositsByWithdrawalAddress[_withdrawalAddress];
    }
}
