// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "../lib/forge-std/src/Test.sol";
import {CombinedEscrow, IERC20, RefundEscrow} from "../src/CombinedEscrow.sol";
import {SimpleToken, ERC20} from "../src/utils/SimpleToken.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
contract BaseCombinedEscrowTest is Test {
    CombinedEscrow public escrow;
    address public _owner;
    address public _beneficiary;
    address payable public _vault;
    address user;

    SimpleToken public _tok;

    uint256 public _initialTokenSupply;

    function setUp() public {
        _owner = address(0xFF);
        _beneficiary = payable(address(0x1));
        _vault = payable(address(0x2));
        (user, ) = makeAddrAndKey("user");

        vm.startPrank(_owner);

        // Create & mint test tokens
        _initialTokenSupply = 100 ether;
        //TODO: review why the event emitting is not working.
        // vm.expectEmit(false, true, false, false);
        // emit IERC20.Transfer(address(0), _owner, _initialTokenSupply);
        _tok = new SimpleToken(_initialTokenSupply);
        // assertEq(false, true, "me");
        // Create Combined Escrow for test token & ether
        // @dev check topic1 & topic2
        vm.expectEmit(true, true, false, false);
        emit Ownable.OwnershipTransferred(address(0x0), address(0xff));
        emit CombinedEscrow.NewEscrowCreated(_beneficiary, address(_tok));
        escrow = new CombinedEscrow(
            _vault, // address for the fee
            payable(_beneficiary),
            address(_tok)
        );
        vm.stopPrank();

        // Initial Assertions
        assertEq(
            address(escrow) != address(0),
            true,
            "Address Initalization Failure"
        );
        assertEq(
            escrow.state() == RefundEscrow.State.Active,
            true,
            "BaseCombinedEscrowTest: Initial State Errore"
        );
        assertEq(escrow.vault(), _vault, "Failure: Vault Address");
        assertEq(
            escrow.beneficiary(),
            _beneficiary,
            "Failure: Beneficiary Address"
        );
        assertEq(
            escrow.saleToken(),
            address(_tok),
            "Failure: SaleToken Address"
        );

        assertEq(
            address(_tok) != address(0x0),
            true,
            "Failure: SimpleToken Address"
        );
        assertEq(
            _tok.balanceOf(_owner),
            _initialTokenSupply,
            "Failure: SimpleToken Initial Balance"
        );

        // Zero Balances
        assertEq(escrow.ethBalance(), 0, "Eth Balance Initialization Failure");
        assertEq(
            escrow.erc20Balance(),
            0,
            "ERC20 Balance Initialization Failure"
        );
    }
}
