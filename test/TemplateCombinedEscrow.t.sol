//SP
pragma solidity ^0.8.24;

import {BaseCombinedEscrowTest} from "test/BaseCombinedEscrow.t.sol";
import {EscrowFunctions} from "test/utils/EscrowFunctions.t.sol";
import {TypeValidation} from "test/utils/TypeValidation.t.sol";
contract TemplateCombinedEscrow is
    BaseCombinedEscrowTest,
    EscrowFunctions,
    TypeValidation
{}
