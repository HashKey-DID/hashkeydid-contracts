// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

/// @title A storage contract for didv2
/// @dev include mapping from id to address and address to id
contract DidV2Storage {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    address public owner;

    string public baseURI_;

    // Deprecated
    mapping(string => bool) public didClaimed;
    // Deprecated
    mapping(address => bool) public addrClaimed;

    mapping(uint256 => string) public tokenId2Did;

    mapping(string => uint256) public did2TokenId;

    address public signer;

    address public dgMinter;

    address public didMinter;

    mapping(address => address) public deedGrainAddrToIssuer;

    mapping(bytes32 => bool) _evidenceUsed;

    mapping(uint256 => EnumerableSetUpgradeable.AddressSet) _auths;

    struct KYCInfo {
        bool status;
        uint updateTime;
        uint expireTime;
    }

    mapping(uint256 => mapping(address => mapping(uint256 => KYCInfo))) _KYCMap;

    address public dgFactory;

    address public resolver;

    address public didSync;
}
