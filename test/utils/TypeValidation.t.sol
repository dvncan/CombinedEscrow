// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

abstract contract TypeValidation {
    // checks != 0
    error InputValidationError();
    error OverflowBlocked();
    event debug(uint256 a, uint256 b);
    event dbug(int256 c);
    function validateAddress(address a) internal pure {
        if (a == address(0)) revert InputValidationError();
    }

    function validateAddressStrict(address a) internal pure {
        if (uint256(uint160((a))) < (160)) revert InputValidationError();
    }

    // Strict checks >= 0
    function validateAmountStrictPositive(uint a) internal pure {
        if (a <= 0) revert InputValidationError();
    }

    // @param: b is current balance
    function validateNewBalanceOverflow(
        uint256 a,
        uint256 b
    ) internal returns (bool) {
        // Check for overflow;
        uint256 newBalance = b + a;
        emit debug(newBalance, b);
        if (newBalance < b) return false;
        return true;
    }

    // checks > 0
    function validateAmountPositive(uint a) internal pure {
        if (a < 0) revert InputValidationError();
    }
}
