// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

import "../libs/SafeMath.sol";
import "../libs/Address.sol";
import "../libs/SafeERC20.sol";
import "../interfaces/IERC20.sol";

contract LPTokenWrapper {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public wault = IERC20(0xCa3F508B8e4Dd382eE878A314789373D80A5190A);

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function stake(uint256 amount) virtual public {
        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        wault.safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) virtual public {
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        wault.safeTransfer(msg.sender, amount);
    }
}
