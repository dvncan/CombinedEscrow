// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract SimpletToken is ERC20 {
    constructor() ERC20("Simple", "SIMP") {
        _mint(msg.sender, 100 ether);
    }
}
