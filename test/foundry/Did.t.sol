// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { DidV2 } from "../../contracts/Did.sol";
import { DidV2Storage } from "../../contracts/DidStorage.sol";
import { Resolver } from "/Users/quanrong/hashkeydid-workplace/resolver/contracts/Resolver.sol";
import { DeedGrain } from "../..//contracts/DeedGrain.sol";

interface IDeedGrain {
    function balanceOf(address, uint256) external view returns(uint256);
}

contract DidV2Test is Test {
    DidV2 did;
    Resolver resolver;
    uint256 signerPri = 0xAA;
    address signer = vm.addr(signerPri);
    address owner = address(this);
    IDeedGrain deedGrain;
    
    DidV2Storage.KYCInfo KYCInfo;
    address[] addrs;
    address[] KYCProviders;
    uint256[] KYCIds;
    DidV2Storage.KYCInfo[] KYCInfos;
    bytes[] evidences;

    function setUp() public {
        did = new DidV2();
        did.initialize("Did","Did","baseuri",owner);
        resolver = new Resolver();
        resolver.initialize(address(did));
        did.setResolverAddr(address(resolver));
        did.setSigner(signer);
        did.setDidMinterAddr(address(this));
    }

    function testClaim() public payable {
        uint256 expiredTimestamp = block.timestamp + 1 days;
        bytes32 hash = keccak256(abi.encodePacked(address(this), block.chainid, expiredTimestamp, "did.key", msg.value));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPri, hash);
        v = v - 27;
        bytes memory signature = abi.encodePacked(r,s,v);
        did.claim(expiredTimestamp, "did.key", signature, "avatar");
        assertEq(did.balanceOf(address(this)), 1);
    }

    function testSetDGMinterAddr() public {
        did.setDGMinterAddr(address(0x11));
        assertEq(did.dgMinter(), address(0x11));
    }

    function testIssueDG() public {
        string memory _name = "test";
        string memory _symbol = "T";
        string memory _baseURI = "https://test.com/";
        bytes32 hash = keccak256(abi.encodePacked(address(this), _name, _symbol, _baseURI, block.chainid));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPri, hash);
        v = v - 27;
        bytes memory signature = abi.encodePacked(r,s,v);
        
        vm.recordLogs();
        did.issueDG(_name, _symbol, _baseURI, signature, false);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(address(uint160(uint256(entries[0].topics[1]))), address(this));
        bytes memory _test = entries[0].data;
        address b;
        assembly {
            b := mload(add(_test, 0x20))
        }
        addrs.push(address(this));
        did.mintDGV2(b, 1, addrs, "0x");
    }

    function testMintDidLZ() public {
        uint256 tokenId = 1;
        uint256 KYCId = 1;
        KYCProviders.push(signer);
        DidV2Storage.KYCInfo memory info = DidV2Storage.KYCInfo(true, block.timestamp, block.timestamp + 1 days);
        KYCInfos.push(info);
        KYCIds.push(KYCId);
        bytes32 hash = keccak256(abi.encodePacked(tokenId, KYCProviders[0], KYCIds[0], KYCInfos[0].status, KYCInfos[0].updateTime, KYCInfos[0].expireTime));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPri, hash);
        v = v - 27;
        bytes memory signature = abi.encodePacked(r,s,v);

        evidences.push(signature);

        did.mintDidLZ(tokenId, address(this), "did.key", "avatar.com", KYCProviders, KYCIds, KYCInfos, evidences);
    }
}