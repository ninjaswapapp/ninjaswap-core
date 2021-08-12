// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract XNinjaSwap is ERC20("XNinjaSwap", "XNINJA"), Ownable {
    using SafeMath for uint256;
    uint256 public maxSupply = 7600000000000000000000000; // 7.6 Million
    uint256 public totalMinted;
    address public current_minter = address(0);
    address public MasterChef = address(0);
    bool public allowedMinting = true;

    constructor() public {
        current_minter = _msgSender();
    }

    function mint(address _to, uint256 _amount) public onlyMinter {
        require(allowedMinting == true && totalMinted.add(_amount) <= maxSupply);
        totalMinted = totalMinted.add(_amount);
        _mint(_to, _amount);
        if (totalMinted == maxSupply) {
            allowedMinting = false;
        }
    }

    function burn(uint256 amount) external onlyOwner {
        _burn(_msgSender(), amount);
    }

    function replaceMinter(address newMinter) external onlyOwner {
        current_minter = newMinter;
    }
    
    function updateMinting(bool _status) external onlyOwner {
        allowedMinting = _status;
    }

    function replaceMasterChef(address newMasterChef) external onlyOwner {
        MasterChef = newMasterChef;
    }

    modifier onlyMinter() {
        require(
            MasterChef == _msgSender() || current_minter == _msgSender(),
            "onlyMinter: caller is not the minter"
        );
        _;
    }
}