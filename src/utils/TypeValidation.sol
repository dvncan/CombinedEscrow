// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

abstract contract TypeValidation {
    // checks != 0
    error InputValidationError();
    error OverflowBlocked();
    error UnderflowBlock();
    event debug(uint256 a, uint256 b);
    event dbug(int256 c);
    function validateAddress(address a) internal pure {
        if (a == address(0)) revert InputValidationError();
    }

    function validateAddressStrict(address a) internal pure {
        if (uint256(uint160((a))) < (160)) revert InputValidationError();
    }

    // Strict checks >= 0
    function validateAmountStrictPositive(uint256 a) internal pure {
        if (a <= 0) revert InputValidationError();
    }

    function validateNewBalanceUnderflow(uint256 a, uint256 b) internal pure {
        if (a > b) revert UnderflowBlock();
    }

    function checkNumberForType(int256 a) internal {
        if ((a) < 0) revert("NumberBlock");
        emit dbug(a);
    }

    // @param: b is current balance
    function validateNewBalanceOverflow(
        uint256 a,
        uint256 b
    ) internal returns (bool) {
        // Check for overflow;
        uint256 newBalance = b + a;
        emit debug(newBalance, b);
        if (a + b > type(uint256).max / 2) revert OverflowBlocked();
        return true;
    }

    // checks > 0
    function validateAmountPositive(uint256 a) internal pure {
        if (a < 0) revert InputValidationError();
    }
}
