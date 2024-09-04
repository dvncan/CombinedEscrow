// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "../lib/forge-std/src/Test.sol";
import {CombinedEscrow, RefundEscrow} from "../src/CombinedEscrow.sol";
import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
// import {IERC20} from "../lib/forge-std/src/interfaces/IERC20.sol";

contract CounterTest is Test {
    CombinedEscrow public counter;
    address me;
    tokenMint tok;
    function setUp() public {
        me = address(0x3);

        vm.deal(me, 1 ether);
        vm.startPrank(me);

        tok = new tokenMint();
        counter = new CombinedEscrow(
            payable(address(0x1)),
            payable(address(0x2)),
            address(tok)
        );

        vm.stopPrank();

        assertEq(me, counter.owner(), "stop");
        assertEq(
            counter.state() == RefundEscrow.State.Active,
            true,
            "State issue"
        );
    }

    function test_simpleDeposit() public {
        vm.startPrank(me);
        counter.deposit{value: 10000}(me);
        assertEq(counter.getTotalEthBalance(), 10000, "Balance error");
        tok.approve(address(counter), 10 ether);
        counter.depositERC20(10000, me, me);
        assertEq(counter.getERC20Balance(me), 10000, "Balance error");
        vm.stopPrank();
    }

    function test_multipleDeposit() public {
        uint8 amount = 0xF;
        vm.startPrank(me);
        counter.deposit{value: amount}(me);
        assertEq(counter.getTotalEthBalance(), amount, "Balance error");
        counter.deposit{value: amount}(me);
        assertEq(counter.getTotalEthBalance(), 2 * amount, "Balance error");
        counter.deposit{value: amount}(me);
        assertEq(counter.getTotalEthBalance(), 3 * amount, "Balance error");
        vm.stopPrank();
    }

    function test_stateClose() public {
        vm.startPrank(me);
        counter.close();
        vm.stopPrank();
        assertEq(
            counter.state() == RefundEscrow.State.Closed,
            true,
            "State issue"
        );
    }

    function testFail_withdraw() public {
        // failure as withdraw is for token refund not close
        test_simpleDeposit();
        test_stateClose();
        vm.startPrank(me);
        counter.withdraw(payable(me));
        assertEq(me.balance, 1 ether, "stop");
    }

    function test_withdrawErc() public {
        // failure as withdraw is for token refund not close
        test_simpleDeposit();
        test_stateClose();
        vm.startPrank(me);
        assertEq(tok.balanceOf(me), 100 ether - 10000, "stop - ERC balance");
        counter.withdrawERC20(me);
        assertEq(me.balance, 1 ether - 10000, "stop - ETH balance");
        assertEq(tok.balanceOf(me), 100 ether, "stop - ERC balance");
    }

    function test_stateRefund() public {
        vm.startPrank(me);
        counter.enableRefunds();
        vm.stopPrank();
        assertEq(
            counter.state() == RefundEscrow.State.Refunding,
            true,
            "State issue"
        );
    }

    function test_simpleWithdraw() public {
        test_simpleDeposit();
        test_stateRefund();
        vm.startPrank(me);
        counter.withdraw(payable(me));
        assertEq(me.balance, 1 ether, "stop");
    }
}

contract tokenMint is ERC20 {
    constructor() ERC20("name", "symbol") {
        _mint(msg.sender, 100 ether);
    }
}
