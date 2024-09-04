// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {CombinedEscrow} from "../src/CombinedEscrow.sol";
import {ERC20} from "lib/openzeppelin-contracts.git/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "lib/forge-std/src/interfaces/IERC20.sol";
contract CounterTest is Test {
    CombinedEscrow public counter;
    address me;
    function setUp() public {
        tokenMint tok = new tokenMint();
        me = address(0x3);
        vm.startPrank(me);
        counter = new CombinedEscrow(
            payable(address(0x1)),
            payable(address(0x2)),
            address(tok)
        );
        vm.stopPrank();
        assertEq(me, counter.owner(), "stop");
    }

    function test_simpleDeposit() public {
        vm.deal(me, 1 ether);
        vm.startPrank(me);
        counter.deposit{value: 10000}(me);
        vm.stopPrank();
    }
}

contract tokenMint is ERC20 {
    constructor() ERC20("name", "symbol") {
        _mint(msg.sender, 100 ether);
    }
}
