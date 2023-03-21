// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.8.0;

/**
 * @dev Revert with an error when caller is not the owner.
 */
uint256 constant OwnershipMismatch = 0x4f776e6572736869704d69736d61746368000000000000000000000000000000;

/**
 * @dev Revert with an error when the evidence is used, the evidence's length
 * is wrong or the the evidence is invalid.
 */
uint256 constant InvalidEvidence = 0x496e76616c696445766964656e63650000000000000000000000000000000000;

/**
 * @dev Revert with an error when call issueDG() but failed in create a
 * new DeedGrain Contract.
 */
uint256 constant DeedGrainIssueFailed = 0x44656564477261696e49737375654661696c6564000000000000000000000000;

/**
 * @dev Revert with an error when caller is lack of permissions to call the
 * function.
 */
uint256 constant InsufficientPermission = 0x496e73756666696369656e745065726d697373696f6e00000000000000000000;