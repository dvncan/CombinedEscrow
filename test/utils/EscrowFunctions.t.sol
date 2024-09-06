// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {CombinedEscrow, IERC20} from "src/CombinedEscrow.sol";
import {SimpleToken} from "src/utils/SimpleToken.sol";
contract EscrowFunctions is Test {
    enum DestructState {
        Inactive,
        Active
    }
    event Burned(DestructState state);

    event Deposited(address indexed payee, uint256 weiAmount);
    event Withdrawn(address indexed payee, uint256 weiAmount);
    event RefundsClosed();
    event RefundsEnabled();

    function user_close_escrow(CombinedEscrow escrow, address _owner) public {
        vm.startPrank(_owner);
        vm.expectEmit();
        emit RefundsClosed();
        escrow.close();
        vm.stopPrank();
    }

    function user_refund_escrow(CombinedEscrow escrow, address _owner) public {
        vm.startPrank(_owner);
        vm.expectEmit();
        emit RefundsEnabled();
        escrow.enableRefunds();
        vm.stopPrank();
    }
    event Pass();
    event Fail();
    function user_deposit_escrow_max(
        CombinedEscrow escrow,
        address u,
        uint256 a,
        uint8 t
    ) public {
        if ((escrow.ethBalance() + a) + t > type(uint256).max / 2) {
            {
                emit Fail();
                user_deposit_escrow_revert(escrow, u, a);
            }
        } else {
            emit Pass();
            user_deposit_escrow_good(escrow, u, a);
        }
    }

    function user_deposit_escrow_good(
        CombinedEscrow escrow,
        address u,
        uint256 a
    ) internal {
        vm.prank(u);
        vm.expectEmit();
        emit Deposited(u, a);
        escrow.deposit{value: a}(u);
    }

    function user_deposit_escrow_revert(
        CombinedEscrow escrow,
        address u,
        uint256 a
    ) public {
        vm.prank(u);
        vm.expectRevert();
        escrow.deposit{value: a}(u);
    }

    function user_withdraw_escrow(
        CombinedEscrow escrow,
        address payable u,
        uint256 a
    ) public {
        vm.prank(u);
        vm.expectEmit();
        emit Withdrawn(u, a);
        escrow.withdraw(u);
    }

    function user_fullWithdraw_escrow(
        CombinedEscrow escrow,
        address payable u,
        uint256 a
    ) public {
        vm.prank(u);
        vm.expectEmit(true, true, true, true);
        emit Withdrawn(u, a);
        emit Burned(DestructState.Active);
        escrow.withdraw(u);
    }

    function user_depositErc_escrow(
        CombinedEscrow escrow,
        address _tok,
        address u,
        uint256 a
    ) public {
        vm.startPrank(u);
        vm.expectEmit();
        emit IERC20.Approval(u, address(escrow), a);
        IERC20(_tok).approve(address(escrow), a);
        vm.expectEmit();
        emit Deposited(u, a);
        escrow.depositERC20(a, u, u);
        vm.stopPrank();
        // escrow.deposit{value: a}(u);
    }

    function user_withdrawErc_escrow(
        CombinedEscrow escrow,
        address u,
        uint256 a
    ) public {
        vm.prank(u);
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(escrow), u, a);
        emit Withdrawn(u, a);
        emit Burned(DestructState.Active);
        escrow.withdrawERC20(u);
    }
}
