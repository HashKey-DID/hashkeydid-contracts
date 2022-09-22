// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.8.0;

interface IDeedGrainNFT {
    function setSupply(uint256 supply) external;

    function setBaseUri(string memory baseUri) external;

    function mint(address to, uint256 sid) external;
}
