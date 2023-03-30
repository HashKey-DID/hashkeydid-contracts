// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.8.0;

import "./DeedGrain.sol";
import "./DeedGrainNFT.sol";

contract DeedGrainFactory {
    function issueDG(
        string memory _name,
        string memory _symbol,
        string memory _baseUri,
        bool _transferable
    ) public returns (address) {
        DeedGrain DG = new DeedGrain(_name, _symbol, _baseUri, _transferable);
        return address(DG);
    }

    function issueNFT(
        string memory _name,
        string memory _symbol,
        string memory _baseUri,
        uint256 _supply
    ) public returns (address) {
        DeedGrainNFT NFT = new DeedGrainNFT(_name, _symbol, _baseUri, _supply);
        return address(NFT);
    }
}
