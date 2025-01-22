//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

contract MyContract is ERC4626 {
    constructor(address _token) ERC4626(IERC20Metadata(_token)) ERC20("BoltShares", "BLTS") {}
}