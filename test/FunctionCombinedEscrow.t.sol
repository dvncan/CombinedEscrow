// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "../lib/forge-std/src/Test.sol";
import {BaseCombinedEscrowTest} from "./BaseCombinedEscrow.t.sol";
import {SimpleToken, ERC20} from "../src/utils/SimpleToken.sol";
import {IERC20} from "lib/forge-std/src/interfaces/IERC20.sol";
import {EscrowFunctions} from "./utils/EscrowFunctions.t.sol";
import {TypeValidation} from "./utils/TypeValidation.t.sol";
import {CombinedEscrow} from "../src/CombinedEscrow.sol";
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

    function test_withdraw(uint amount) public {
        amount = bound(amount, 1, 1e39);
        vm.deal(user, amount);
        user_deposit_escrow_good(escrow, user, amount);
        user_refund_escrow(escrow, _owner);
        user_withdraw_escrow(escrow, payable(user), amount);

        assertEq(user.balance, amount, "Fail");
    }
    function test_withdrawDestruct(uint amount) public {
        amount = bound(amount, 1, 1e39);

        vm.deal(user, amount);
        user_deposit_escrow_good(escrow, user, amount);
        user_refund_escrow(escrow, _owner);
        user_fullWithdraw_escrow(escrow, payable(user), amount);

        assertEq(user.balance, amount, "Fail");
    }

    function test_depositErc(uint256 amount) public {
        amount = bound(amount, 1, 1 ether);
        // vm.assume(amount < )
        vm.deal(user, amount);

        user_depositErc_escrow(escrow, address(_tok), user, amount);
        // 10 ether is transferred to user in the Base... setUp() tfr 10 - amount
        assertEq(_tok.balanceOf(user), 10 ether - amount, "Fail");
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

    function test_depositErc_withdraw() public {
        // Test ERC20 deposit and withdrawal
        // 1. Deposit ERC20 tokens
        // 2. Refund the escrow
        // 3. Withdraw ERC20 tokens
        // 4. Assert correct balances
    }

    function test_multipleDeposits_singleWithdraw() public {
        // Test multiple deposits from different users and single withdrawal
        // 1. Deposit from user1
        // 2. Deposit from user1
        // 3. Refund the escrow
        // 4. Withdraw all funds to a single address
        // 5. Assert correct balances
    }

    function test_partialWithdrawal() public {
        // Test partial withdrawal of funds
        // 1. Deposit from user1
        // 2. Deposit from user2
        // 2. Refund the escrow
        // 3. Withdraw a portion of the funds user1
        // 4. Assert correct balances
        // 5. Withdraw the remaining funds to user2
        // 6. Assert final balances
    }
    function testReentrancyProtection() public {
        // Create a malicious contract that tries to re-enter the withdraw function
        MaliciousContract maliciousContract = new MaliciousContract(
            address(escrow)
        );

        // Deposit funds
        uint256 depositAmount = 1 ether;
        vm.deal(address(maliciousContract), depositAmount);
        vm.prank(address(maliciousContract));
        maliciousContract.deposit{value: depositAmount}();

        // Refund the escrow
        user_refund_escrow(escrow, _owner);

        // Attempt to withdraw using the malicious contract
        // vm.expectRevert("revert: ReentrancyGuard: reentrant call");
        vm.expectRevert(); // "revert: ReentrancyGuard: reentrant call"
        vm.prank(address(maliciousContract));
        escrow.withdraw(payable(address(maliciousContract)));

        // Assert that the reentrancy attack failed
        assertEq(
            address(escrow).balance,
            depositAmount,
            "Escrow balance should remain unchanged"
        );
        assertEq(
            address(maliciousContract).balance,
            0,
            "Malicious contract should not receive funds"
        );
    }
}
// Malicious contract for testing reentrancy
contract MaliciousContract {
    CombinedEscrow private immutable escrow;
    uint256 private constant ATTACK_COUNT = 3;
    uint256 private attackCounter;

    constructor(address _escrow) {
        escrow = CombinedEscrow(payable(_escrow));
    }

    function deposit() external payable {
        escrow.deposit{value: msg.value}(address(this));
    }

    receive() external payable {
        if (attackCounter < ATTACK_COUNT) {
            attackCounter++;
            escrow.withdraw(payable(address(this)));
        }
    }
}
