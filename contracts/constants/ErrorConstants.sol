// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.8.0;

uint256 constant Error_selector_offset = 0x1c;

/*
 *  error OwnershipMismatch()
 *    - Defined in ../interfaces/Errors.sol
 *  Memory layout:
 *    - 0x00: Left-padded selector (data begins at 0x1c)
 *    - 0x20: side
 * Revert buffer is memory[0x1c:0x20]
 */
uint256 constant OwnerShipMismatch_error_selector = 0x892acadf;
uint256 constant OwnerShipMismatch_error_length = 0x04;