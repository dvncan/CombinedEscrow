// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BaseCombinedEscrowTest} from "./BaseCombinedEscrow.t.sol";
import {Escrow} from "src/oz-escrow/Escrow.sol";
import {EscrowFunctions} from "./utils/EscrowFunctions.t.sol";
import {TypeValidation} from "./utils/TypeValidation.t.sol";
contract FunctionBaseCombinedEscrowTest is
    BaseCombinedEscrowTest,
    EscrowFunctions,
    TypeValidation
{
    //who_function_where

    function test_deposit(uint amount) public {
        amount = bound(amount, 1, 1e39);
        vm.deal(user, amount);
        user_deposit_escrow_good(escrow, user, amount);
        assertEq(escrow.ethBalance(), amount, "Fail");
        assertEq(user.balance, 0, "Fail");
    }

    function test_withdraw_refund(uint amount) public {
        amount = bound(amount, 1, 1e39);
        vm.deal(user, amount);
        user_deposit_escrow_good(escrow, user, amount);
        user_refund_escrow(escrow, _owner);
        user_withdraw_escrow(escrow, payable(user), amount);

        assertEq(user.balance, amount, "Fail");
    }
    function test_withdrawDestruct_refund(uint amount) public {
        amount = bound(amount, 1, 1e39);

        vm.deal(user, amount);
        user_deposit_escrow_good(escrow, user, amount);
        user_refund_escrow(escrow, _owner);
        user_fullWithdraw_escrow(escrow, payable(user), amount);

        assertEq(user.balance, amount, "Fail");
    }

    function test_deposit_largerBalance() public {
        uint256 smaller = 1 ether;
        uint256 larger = 2 ether;
        vm.deal(user, smaller);
        user_deposit_escrow_revert(escrow, user, larger);
        assertEq(user.balance, smaller, "Fail");
    }
    function test_deposit_max() public {
        uint256 maxAmount = uint256(type(int256).max);
        vm.deal(user, uint256(type(int256).max));
        user_deposit_escrow_revert(escrow, user, maxAmount);
        assertEq(user.balance, maxAmount, "Fail");
    }

    function test_max(uint8 t) public {
        // while fail == 0 it will not disrupt the final assert
        uint256 count;
        for (uint i = 1; i < t; i++) {
            uint256 maxAmount = uint256(type(int256).max) / t;
            vm.deal(user, uint256(type(int256).max));
            user_deposit_escrow_max(escrow, user, maxAmount, t);
            count += maxAmount;
        }
        assertEq(count, escrow.ethBalance(), "Fail?");
    }

    function test_deposit_negative() public {
        int256 amount = -1;
        uint256 maxAmount = uint256(type(int256).max);
        vm.deal(user, maxAmount);
        user_deposit_escrow_revert(escrow, user, uint256(amount));
        assertEq(user.balance, maxAmount, "Fail");
    }
    function test_depositErc(uint256 amount) public {
        amount = bound(amount, 1, 1 ether);
        // vm.assume(amount < )
        vm.deal(user, amount);
        user_depositErc_escrow(escrow, address(_tok), user, amount);
        // 10 ether is transferred to user in the Base... setUp() tfr 10 - amount
        assertEq(_tok.balanceOf(user), 10 ether - amount, "Fail");
        assertEq(escrow.erc20Balance(), amount, "Fail");
    }
    function test_depositErc_withdraw(uint256 amount) public {
        // Test ERC20 deposit and withdrawal
        // 1. Deposit ERC20 tokens
        // 2. Close the escrow
        // 3. Withdraw ERC20 tokens
        // 4. Assert correct balances
        amount = bound(amount, 1, 1 ether);
        vm.deal(user, amount);
        user_depositErc_escrow(escrow, address(_tok), user, amount);
        assertEq(escrow.erc20Balance(), amount, "Fail");
        user_close_escrow(escrow, _owner);

        user_withdrawErc_escrow(escrow, user, amount);
        assertEq(escrow.depositsOf(user), 0, "Fail");
        assertEq(_tok.balanceOf(user), 10 ether, "Fail");
    }
}
