// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.8.0;

/**
 * @title Errors
 * @notice Errors contains errors related to did application and deedgrain
 *         issuer.
 */
interface Errors {
    /**
     * @dev Revert with an error when caller is not the owner.
     */
    error OwnershipMismatch();

    /**
     * @dev Revert with an error when the evidence is used, the evidence's length
     * is wrong or the the evidence is invalid.
     */
    error InvalidEvidence();

    /**
     * @dev Revert with an error when call issueDG() but failed in create a
     * new DeedGrain Contract.
     */
    error DeedGrainIssueFailed();

    /**
     * @dev Revert with an error when caller is lack of permissions to call the
     * function.
     */
    error InsufficientPermission();
}