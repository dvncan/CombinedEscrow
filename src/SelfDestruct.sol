// SPDX-License-Identifier: BONSAI3
pragma solidity >=0.8.19;

abstract contract SelfDestruct {
    enum SelfDestruct {
        Inactive,
        Active
    }

    function burnAfterReading() internal virtual;

    event Burned(SelfDestruct state);
}
