// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.8.0;

import "./Errors.sol";

/**
 * @dev Revert with an error when caller is not the owner.
 */
function _revertOwnershipMismatch() pure {
    assembly {
        mstore(0, Error_Selector)
        mstore(0x20, 0x20)
        mstore(0x40, OwnershipMismatch_Err_Length)
        mstore(0x60, OwnershipMismatch_Err_Message)
        revert(0x1c, 0x64)
    }
}

/**
 * @dev Revert with an error when the evidence is used, the evidence's length
 * is wrong or the the evidence is invalid.
 */
function _revertInvalidEvidence() pure {
    assembly {
        mstore(0, Error_Selector)
        mstore(0x20, 0x20)
        mstore(0x40, InvalidEvidence_Err_Length)
        mstore(0x60, InvalidEvidence_Err_Message)
        revert(0x1c, 0x64)
    }
}

/**
 * @dev Revert with an error when call issueDG() but failed in create a
 * new DeedGrain Contract.
 */
function _revertDeedGrainIssueFailed() pure {
    assembly {
        mstore(0, Error_Selector)
        mstore(0x20, 0x20)
        mstore(0x40, DeedGrainIssueFailed_Err_Length)
        mstore(0x60, DeedGrainIssueFailed_Err_Message)
        revert(0x1c, 0x64)
    }
}

/**
 * @dev Revert with an error when caller is lack of permissions to call the
 * function.
 */
function _revertInsufficientPermission() pure {
    assembly {
        mstore(0, Error_Selector)
        mstore(0x20, 0x20)
        mstore(0x40, InsufficientPermission_Err_Length)
        mstore(0x60, InsufficientPermission_Err_Message)
        revert(0x1c, 0x64)
    }
}