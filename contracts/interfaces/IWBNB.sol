// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "../interfaces/IERC20.sol";

interface IWBNB is IERC20 {
    function deposit() external payable;
    function withdraw(uint wad) external;
}
