// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "../lib/forge-std/src/Test.sol";
import "../src/CombinedEscrow.sol";
import {SimpletToken} from "./utils/SimpleToken.sol";

contract EscrowTest is Test {
    CombinedEscrow public escrow;
    address private _owner;
    address private _payee;
    address private _bob;
    uint256 private _alicePk;
    uint256 private _bobPk;
    address private _beneficiary;
    address payable private _vault;

    SimpletToken private _tok;

    function setUp() public {
        _owner = address(0xFF);
        _beneficiary = payable(address(0x1));
        // trade Ether for ERC20
        _payee = payable(address(0x2));
        _vault = payable(address(0x3));
        vm.startPrank(_owner);
        _tok = new SimpletToken();
        _tok.transfer(_payee, 100 ether);
        escrow = new CombinedEscrow(
            _vault,
            payable(_beneficiary),
            address(_tok)
        );
        // Fund the accounts
        vm.deal(_owner, 100 ether);
        vm.deal(_payee, 100 ether);

        // Mint and approve tokens for escrow
        _tok.approve(address(escrow), type(uint256).max);
        vm.stopPrank();
    }

    function testSimpleDeposit() public {
        vm.startPrank(_payee);
        escrow.deposit{value: 10000}(_payee);
        assertEq(escrow.getTotalEthBalance(), 10000, "Balance error");
        _tok.approve(address(escrow), 10 ether);
        escrow.depositERC20(10000, _payee, _payee);
        assertEq(escrow.getERC20Balance(_payee), 10000, "Balance error");
        vm.stopPrank();
    }

    function testMultipleDeposit() public {
        uint8 amount = 0xF;
        vm.startPrank(_payee);
        escrow.deposit{value: amount}(_payee);
        assertEq(escrow.getTotalEthBalance(), amount, "Balance error");
        escrow.deposit{value: amount}(_payee);
        assertEq(escrow.getTotalEthBalance(), 2 * amount, "Balance error");
        escrow.deposit{value: amount}(_payee);
        assertEq(escrow.getTotalEthBalance(), 3 * amount, "Balance error");
        vm.stopPrank();
    }

    function testStateClose() public {
        vm.startPrank(_owner);
        escrow.close();
        assertEq(
            escrow.state() == RefundEscrow.State.Closed,
            true,
            "State issue"
        );
        vm.stopPrank();
    }

    function testFailWithdraw() public {
        // failure as withdraw is for token refund not close
        testSimpleDeposit();
        testStateClose();
        vm.startPrank(_payee);
        escrow.withdraw(payable(_payee));
        assertEq(_payee.balance, 1 ether, "stop");
    }
    function test_withdrawErc() public {
        testSimpleDeposit();
        testStateClose();
        vm.startPrank(_payee);
        assertEq(
            _tok.balanceOf(_payee),
            100 ether - 10000,
            "stop - ERC balance before"
        );
        // Expect the call to succeed but the contract to be destroyed

        // Expect the Withdrawn event to be emitted
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(escrow), _payee, 10000);
        emit CombinedEscrow.Withdrawal(_payee, 10000);
        emit SelfDestruct.Burned(SelfDestruct.DestructState.Active);
        escrow.withdrawERC20(_payee);

        // Check final balance
        assertEq(_tok.balanceOf(_payee), 100 ether, "stop - ERC balance after");

        vm.stopPrank();
    }
    function testStateRefund() public {
        vm.startPrank(_owner);
        escrow.enableRefunds();
        vm.stopPrank();
        assertEq(
            escrow.state() == RefundEscrow.State.Refunding,
            true,
            "State issue"
        );
    }

    function test_simpleWithdraw() public {
        testSimpleDeposit();
        testStateRefund();
        vm.startPrank(_payee);
        escrow.withdraw(payable(_payee));
        assertEq(_payee.balance, 100 ether, "stop");
    }
}
