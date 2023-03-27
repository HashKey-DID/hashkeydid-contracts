// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.8.0;

import {DeedGrain} from "./DeedGrain.sol";
import "./DeedGrainNFT.sol";

contract DeedGrainFactory {
    function issueDG(
        string memory _name,
        string memory _symbol,
        string memory _baseUri,
        bool _transferable
    ) public returns (address deploymentAddress) {
        // DeedGrain DG = new DeedGrain(_name, _symbol, _baseUri, _transferable);
        // return address(DG);
        bytes memory bytecode = abi.encodePacked(
            type(DeedGrain).creationCode,
            abi.encode(_name, _symbol, _baseUri, _transferable)
        );
        assembly{
            deploymentAddress := create(0, add(0x20, bytecode), mload(bytecode))
        }
        require(deploymentAddress != address(0));
    }

    function issueNFT(
        string memory _name,
        string memory _symbol,
        string memory _baseUri,
        uint256 _supply
    ) public returns (address deploymentAddress) {
        // DeedGrainNFT NFT = new DeedGrainNFT(_name, _symbol, _baseUri, _supply);
        // return address(NFT);
        bytes memory bytecode = abi.encodePacked(
            type(DeedGrainNFT).creationCode,
            abi.encode(_name, _symbol, _baseUri, _supply)
        );
        assembly{
            deploymentAddress := create(0, add(0x20, bytecode), mload(bytecode))
        }
        require(deploymentAddress != address(0));
    }
}
