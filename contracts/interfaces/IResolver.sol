// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.8.0;

interface IResolver {
    function setAvatar(uint256 tokenId, string calldata value) external;
}
