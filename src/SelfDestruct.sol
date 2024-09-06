// SPDX-License-Identifier: BONSAI3
pragma solidity >=0.8.19;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
/*********************************************************************************
 *                                                                               *
 *                           █████████████████████████████████                   *
 *                           █                                                   *
 *                           █   contract SelfDestruct {                     *
 *                           █     enum DestructState {                           *
 *                           █           Inactive,                               *
 *                           █           Active                                  *
 *                           █     }                                             *
 *                           █     function burnAfterReading() internal virtual; *
 *                           █     event Burned(SelfDestruct state);             *
 *                           █   }                                               *
 *                           █                                                   *
 *                           █████████████████████████████████                   *
 *                                                                               *
 *********************************************************************************/

contract SelfDestruct is Ownable {
    enum DestructState {
        Inactive,
        Active
    }
    event Burned(DestructState state);

    //@dev _current can only be flipped when contract is closed
    DestructState private _current;
    modifier contractNotDestroyed() {
        require(
            _current == DestructState.Inactive,
            "CombinedEscrow: Contract has been destroyed"
        );
        _;
    }

    // Internal functions to manage contract destruction when do i call this?
    function _burnAfterReading() internal contractNotDestroyed {
        // Implement the logic here
        // For example:
        require(_current == DestructState.Inactive, "Already burned");
        _current = DestructState.Active;
        emit Burned(_current);

        selfdestruct(payable(owner())); // Send remaining Ether to the owner
    }
}
