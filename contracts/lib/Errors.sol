// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.8.0;

import "./ErrorConstants.sol";

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

/**
 * @dev Revert with an error when input a zero address which is not invalid.
 */
    function _revertZeroAddress() pure {
        assembly {
            mstore(0, Error_Selector)
            mstore(0x20, 0x20)
            mstore(0x40, ZeroAddress_Err_Message)
            mstore(0x60, ZeroAddress_Err_Length)
            revert(0x1c, 0x64)
        }
    }

/**
 * @dev Revert with an error when DID name is illegal.
 */
    function _revertIllegalDIDName() pure {
        assembly {
            mstore(0, Error_Selector)
            mstore(0x20, 0x20)
            mstore(0x40, IllegalDIDName_Err_Message)
            mstore(0x60, IllegalDIDName_Err_Length)
            revert(0x1c, 0x64)
        }
    }

/**
 * @dev Revert with an error when DID name is already registered by others.
 */
    function _revertRegisteredDIDName() pure {
        assembly {
            mstore(0, Error_Selector)
            mstore(0x20, 0x20)
            mstore(0x40, RegisteredDIDName_Err_Message)
            mstore(0x60, RegisteredDIDName_Err_Length)
            revert(0x1c, 0x64)
        }
    }

/**
 * @dev Revert with an error when the caller has been registered.
 */
    function _revertRegisteredAddress() pure {
        assembly {
            mstore(0, Error_Selector)
            mstore(0x20, 0x20)
            mstore(0x40, RegisteredAddress_Err_Message)
            mstore(0x60, RegisteredAddress_Err_Length)
            revert(0x1c, 0x64)
        }
    }

/**
 * @dev Revert with an error when user try to transfer DID.
 */
    function _revertNontransferableDID() pure {
        assembly {
            mstore(0, Error_Selector)
            mstore(0x20, 0x20)
            mstore(0x40, NontransferableDID_Err_Message)
            mstore(0x60, NontransferableDID_Err_Length)
            revert(0x1c, 0x64)
        }
    }
