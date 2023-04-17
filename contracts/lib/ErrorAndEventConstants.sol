// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.8.0;

uint256 constant Error_Selector = 0x08c379a0;

/**
 * @dev Revert with an error when caller is not the owner.
 */
uint256 constant OwnershipMismatch_Err_Message = 0x4f776e6572736869704d69736d61746368000000000000000000000000000000;
uint256 constant OwnershipMismatch_Err_Length = 0x11;

/**
 * @dev Revert with an error when the evidence is used, the evidence's length
 * is wrong or the the evidence is invalid.
 */
uint256 constant InvalidEvidence_Err_Message = 0x496e76616c696445766964656e63650000000000000000000000000000000000;
uint256 constant InvalidEvidence_Err_Length = 0x0f;

/**
 * @dev Revert with an error when call issueDG() but failed in create a
 * new DeedGrain Contract.
 */
uint256 constant DeedGrainIssueFailed_Err_Message = 0x44656564477261696e49737375654661696c6564000000000000000000000000;
uint256 constant DeedGrainIssueFailed_Err_Length = 0x14;

/**
 * @dev Revert with an error when caller is lack of permissions to call the
 * function.
 */
uint256 constant InsufficientPermission_Err_Message = 0x496e73756666696369656e745065726d697373696f6e00000000000000000000;
uint256 constant InsufficientPermission_Err_Length = 0x16;

/**
 * @dev Revert with an error when input a zero address which is not invalid.
 */
uint256 constant ZeroAddress_Err_Message = 0x5a65726f41646472657373000000000000000000000000000000000000000000;
uint256 constant ZeroAddress_Err_Length = 0x0b;

/**
 * @dev Revert with an error when DID name is illegal.
 */
uint256 constant IllegalDIDName_Err_Message = 0x496c6c6567616c4449444e616d65000000000000000000000000000000000000;
uint256 constant IllegalDIDName_Err_Length = 0x0e;

/**
 * @dev Revert with an error when DID name is already registered by others.
 */
uint256 constant RegisteredDIDName_Err_Message = 0x526567697374657265644449444e616d65000000000000000000000000000000;
uint256 constant RegisteredDIDName_Err_Length = 0x11;

/**
 * @dev Revert with an error when the caller has been registered.
 */
uint256 constant RegisteredAddress_Err_Message = 0x5265676973746572656441646472657373000000000000000000000000000000;
uint256 constant RegisteredAddress_Err_Length = 0x11;

/**
 * @dev Revert with an error when user try to transfer DID.
 */
uint256 constant NontransferableDID_Err_Message = 0x4e6f6e7472616e7366657261626c654449440000000000000000000000000000;
uint256 constant NontransferableDID_Err_Length = 0x12;

/**
 * @dev Event IssueDG(address, address), emit when issue a new DeedGrain
 * ERC1155 contract. 
 */
uint256 constant EventIssueDG = 0xc05872623594b1c2574e0531d0cc06b56ceb48baddce03b13163aa822ddfd52c;

/**
 * @dev Event IssueDG(address, address), emit when issue a new DeedGrain
 * ERC721 contract. 
 */
uint256 constant EventIssueNFT = 0xf9d4b55952c081f85101e9a2f8c6d5843afd8c96692b343ae78aa9f653090c39;
