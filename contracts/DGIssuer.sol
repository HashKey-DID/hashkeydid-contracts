// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.8.0;

import "./lib/ErrorConstants.sol";

import "./DidStorage.sol";
import "./interfaces/IDeedGrain.sol";
import "./interfaces/IDeedGrainV1.sol";
import "./interfaces/IDeedGrainNFT.sol";

abstract contract DGIssuer is DidV2Storage {
    /// @dev Emitted when issue DG successfully
    event IssueDG(address indexed, address);

    /// @dev Emitted when issue NFT successfully
    event IssueNFT(address indexed, address);

    /// @dev Only owner
    modifier onlyOwner() {
        // require(msg.sender == owner, "caller is not the owner");
        assembly{
            if iszero(eq(caller(), sload(owner.slot))) {
                let err := mload(0x20)
                mstore(err, Error_Selector)
                mstore(add(err, 0x20), 0x20)  // string offset
                mstore(add(err, 0x40), InsufficientPermission_Err_Length)
                mstore(add(err, 0x60), InsufficientPermission_Err_Message)
                revert(add(err, 0x1c), sub(0x80, 0x1c))
            }
        }
        _;
    }

    /// @dev Set DG airdrop address
    /// @param minter DG airdrop address
    function setDGMinterAddr(address minter) public onlyOwner {
        // dgMinter = minter;
        assembly{
            sstore(dgMinter.slot, minter)
        }
    }

    /// @dev Set Resolver address
    /// @param _resolver Resolver address
    function setResolverAddr(address _resolver) public onlyOwner {
        // resolver = _resolver;
        assembly{
            sstore(resolver.slot, _resolver)
        }
    }

    /// @dev Set DID sync address
    /// @param _didSync DID sync address
    function setDidSync(address _didSync) public onlyOwner {
        // didSync = _didSync;
        assembly{
            sstore(didSync.slot, _didSync)
        }
    }

    /// @dev Issue DG token
    /// @param _name ERC1155 NFT name
    /// @param _symbol ERC1155 NFT symbol
    /// @param _baseUri ERC1155 NFT baseUri
    /// @param _evidence Signature by HashKeyDID
    /// @param _transferable DG transferable
    function issueDG(string memory _name, string memory _symbol, string memory _baseUri, bytes memory _evidence, bool _transferable) public {
        bytes32 keccakEvidence;
        assembly{
        // require(!_evidenceUsed[keccak256(_evidence)])
            let ptr := mload(0x40)
            keccakEvidence := keccak256(add(_evidence, 0x20), mload(_evidence))
            mstore(ptr, keccakEvidence)
            mstore(add(ptr, 0x20), _evidenceUsed.slot)
            if sload(keccak256(ptr, 0x40)){
                let err := mload(0x20)
                mstore(err, Error_Selector)
                mstore(add(err, 0x20), 0x20)  // string offset
                mstore(add(err, 0x40), InsufficientPermission_Err_Length)
                mstore(add(err, 0x60), InsufficientPermission_Err_Message)
                revert(add(err, 0x1c), sub(0x80, 0x1c))
            }
        }

        bytes32 hash = keccak256(abi.encodePacked(msg.sender, _name, _symbol, _baseUri, block.chainid));

        assembly {
        // _validate(hash, _evidence, signer)
            let validate := mload(0x40)
            mstore(validate, 0x6d050b00) // Keccak256("_validate(bytes32,bytes,address)")
            mstore(add(validate, 0x20), hash)
            mstore(add(validate, 0x40), 0x60)
            mstore(add(validate, 0x60), sload(signer.slot))
            mstore(add(validate, 0x80), mload(_evidence))
            mstore(add(validate, 0xa0), mload(add(_evidence, 0x20)))
            mstore(add(validate, 0xc0), mload(add(_evidence, 0x40)))
            mstore(add(validate, 0xe0), mload(add(_evidence, 0x60)))
            let calld := add(validate, 0x1c)
            pop(staticcall(gas(), address(), calld, 0x100, 0x20, 0x20))
            if iszero(mload(0x20)) {
                let err := mload(0x20)
                mstore(err, Error_Selector)
                mstore(add(err, 0x20), 0x20)  // string offset
                mstore(add(err, 0x40), InsufficientPermission_Err_Length)
                mstore(add(err, 0x60), InsufficientPermission_Err_Message)
                revert(add(err, 0x1c), sub(0x80, 0x1c))
            }
        }

        assembly{
        // _evidenceUsed[keccak256(_evidence)] = true;
            let ptr := mload(0x40)
            mstore(ptr, keccakEvidence)
            mstore(add(ptr, 0x20), _evidenceUsed.slot)
            let evidenceUsed := keccak256(ptr, 0x40)
            sstore(evidenceUsed, 0x01)
        }

        bytes memory params = abi.encode(_name, _symbol, _baseUri, _transferable);
        assembly{
            mstore(0x40, 0xc875020a) // Keccak256("issueDG(string,string,string,bool)")
            let paramLen := mload(params)
            for {let i := 0} lt(i, add(div(paramLen, 0x20), 1)) {i := add(i, 1)} {
                mstore(add(0x40, mul(0x20, add(i, 1))), mload(add(params, mul(0x20, add(i, 1)))))
            }
            let res := call(gas(), sload(dgFactory.slot), 0, add(0x40, 0x1c), add(paramLen, 0x04), 0x20, 0x20)
            if iszero(res){
                let err := mload(0x20)
                mstore(err, Error_Selector)
                mstore(add(err, 0x20), 0x20)  // string offset
                mstore(add(err, 0x40), DeedGrainIssueFailed_Err_Length)
                mstore(add(err, 0x60), DeedGrainIssueFailed_Err_Message)
                revert(add(err, 0x1c), sub(0x80, 0x1c))
            }

        // deedGrainAddrToIssuer[DGAddr] = msg.sender;
            let addr := mload(0x20)
            mstore(add(addr, 0x20), deedGrainAddrToIssuer.slot)
            sstore(keccak256(addr, 0x40), caller())

        //emit IssueDG(msg.sender, DGAddr);
            log2(
            addr, // data
            0x20,
            0xc05872623594b1c2574e0531d0cc06b56ceb48baddce03b13163aa822ddfd52c, // event topic0
            // hash string is keccak256("IssueDG(address,address)")
            caller() // topic1
            )
        }
        //        require(!_evidenceUsed[keccak256(_evidence)] && _validate(keccak256(abi.encodePacked(msg.sender, _name, _symbol, _baseUri, block.chainid)), _evidence, signer), "invalid evidence");
        //        _evidenceUsed[keccak256(_evidence)] = true;
        //        bool success;
        //        bytes memory data;
        //        (success, data) = dgFactory.delegatecall(
        //            abi.encodeWithSignature(
        //                "issueDG(string,string,string,bool)",
        //                _name,
        //                _symbol,
        //                _baseUri,
        //                _transferable
        //            )
        //        );
        //        require(success, "issueDG failed");
        //        address DGAddr = abi.decode(data, (address));
        //        deedGrainAddrToIssuer[DGAddr] = msg.sender;
        //        emit IssueDG(msg.sender, DGAddr);
    }

    /// @dev Issue DG NFT
    /// @param _name ERC721 NFT name
    /// @param _symbol ERC721 NFT symbol
    /// @param _baseUri ERC721 NFT baseUri
    /// @param _evidence Signature by HashKeyDID
    /// @param _supply DG NFT supply
    function issueNFT(string memory _name, string memory _symbol, string memory _baseUri, bytes memory _evidence, uint256 _supply) public {
        bytes32 keccakEvidence;
        assembly{
        // require(!_evidenceUsed[keccak256(_evidence)])
            let ptr := mload(0x40)
            keccakEvidence := keccak256(add(_evidence, 0x20), mload(_evidence))
            mstore(ptr, keccakEvidence)
            mstore(add(ptr, 0x20), _evidenceUsed.slot)
            if sload(keccak256(ptr, 0x40)){
                let err := mload(0x20)
                mstore(err, Error_Selector)
                mstore(add(err, 0x20), 0x20)  // string offset
                mstore(add(err, 0x40), InsufficientPermission_Err_Length)
                mstore(add(err, 0x60), InsufficientPermission_Err_Message)
                revert(add(err, 0x1c), sub(0x80, 0x1c))
            }
        }

        bytes32 hash = keccak256(abi.encodePacked(msg.sender, _name, _symbol, _baseUri, block.chainid));

        assembly {
        // _validate(hash, _evidence, signer)
            let validate := mload(0x40)
            mstore(validate, 0x6d050b00) // Keccak256("_validate(bytes32,bytes,address)")
            mstore(add(validate, 0x20), hash)
            mstore(add(validate, 0x40), 0x60)
            mstore(add(validate, 0x60), sload(signer.slot))
            mstore(add(validate, 0x80), mload(_evidence))
            mstore(add(validate, 0xa0), mload(add(_evidence, 0x20)))
            mstore(add(validate, 0xc0), mload(add(_evidence, 0x40)))
            mstore(add(validate, 0xe0), mload(add(_evidence, 0x60)))
            let calld := add(validate, 0x1c)
            pop(staticcall(gas(), address(), calld, 0x100, 0x20, 0x20))
            if iszero(mload(0x20)) {
                let err := mload(0x20)
                mstore(err, Error_Selector)
                mstore(add(err, 0x20), 0x20)  // string offset
                mstore(add(err, 0x40), InsufficientPermission_Err_Length)
                mstore(add(err, 0x60), InsufficientPermission_Err_Message)
                revert(add(err, 0x1c), sub(0x80, 0x1c))
            }
        }

        assembly{
        // _evidenceUsed[keccak256(_evidence)] = true;
            let ptr := mload(0x40)
            mstore(ptr, keccakEvidence)
            mstore(add(ptr, 0x20), _evidenceUsed.slot)
            let evidenceUsed := keccak256(ptr, 0x40)
            sstore(evidenceUsed, 0x01)
        }

        bytes memory params = abi.encode(_name, _symbol, _baseUri, _supply);
        assembly{
            mstore(0x40, 0xed254cfc) // Keccak256("issueNFT(string,string,string,uint256)")
            let paramLen := mload(params)
            for {let i := 0} lt(i, add(div(paramLen, 0x20), 1)) {i := add(i, 1)} {
                mstore(add(0x40, mul(0x20, add(i, 1))), mload(add(params, mul(0x20, add(i, 1)))))
            }
            let res := call(gas(), sload(dgFactory.slot), 0, add(0x40, 0x1c), add(paramLen, 0x04), 0x20, 0x20)
            if iszero(res){
                let err := mload(0x20)
                mstore(err, Error_Selector)
                mstore(add(err, 0x20), 0x20)  // string offset
                mstore(add(err, 0x40), DeedGrainIssueFailed_Err_Length)
                mstore(add(err, 0x60), DeedGrainIssueFailed_Err_Message)
                revert(add(err, 0x1c), sub(0x80, 0x1c))
            }

        // deedGrainAddrToIssuer[DGAddr] = msg.sender;
            let addr := mload(0x20)
            mstore(add(addr, 0x20), deedGrainAddrToIssuer.slot)
            sstore(keccak256(addr, 0x40), caller())

        //emit IssueNFT(msg.sender, DGNFTAddr);
            log2(
            addr, // data
            0x20,
            0xf9d4b55952c081f85101e9a2f8c6d5843afd8c96692b343ae78aa9f653090c39, // event topic0, hash string is keccak256("IssueNFT(address,address)")
            caller() // topic1
            )
        }
    }

    /// @dev Set didSigner address
    /// @param signer_ Did singer address
    function setSigner(address signer_) public onlyOwner {
        // signer = signer_;
        assembly{
            sstore(signer.slot, signer_)
        }
    }

    /// @dev Set dgFactory address
    /// @param factory DeedGrainFactory contract address
    function setDGFactory(address factory) public onlyOwner {
        // dgFactory = factory;
        assembly{
            sstore(dgFactory.slot, factory)
        }
    }

    /// @dev Only issuer can set every kind of token's supply
    /// @param DGAddr DG contract address
    /// @param tokenId TokenId
    /// @param supply Token's supply number
    function setTokenSupply(address DGAddr, uint256 tokenId, uint256 supply) public {
        assembly{
            let ptr := mload(0x20)
            mstore(ptr, DGAddr)
            mstore(add(ptr, 0x20), deedGrainAddrToIssuer.slot)
        //require(msg.sender == dgMinter || msg.sender == deedGrainAddrToIssuer[DGAddr],"caller are not allowed to set supply");
            if iszero(or(eq(sload(dgMinter.slot), caller()), eq(sload(keccak256(ptr, 0x40)), caller()))){
                let err := mload(0x20)
                mstore(err, Error_Selector)
                mstore(add(err, 0x20), 0x20)  // string offset
                mstore(add(err, 0x40), InsufficientPermission_Err_Length)
                mstore(add(err, 0x60), InsufficientPermission_Err_Message)
                revert(add(err, 0x1c), sub(0x80, 0x1c))
            }

        // IDeedGrain DG = IDeedGrain(DGAddr);
        // DG.setSupply(tokenId, supply);
            let calld := mload(0x40)
            mstore(calld, 0xfc784d49) // Keccak256("setSupply(uint256,uint256)")
            mstore(add(calld, 0x20), tokenId)
            mstore(add(calld, 0x40), supply)
            calld := add(calld, 0x1c)
            pop(call(gas(), DGAddr, 0, calld, 0x60, 0, 0x20))
        }
    }

    /// @dev Only issuer can set token's baseuri
    /// @param DGAddr DG contract address
    /// @param baseUri All of the token's baseuri
    function setTokenBaseUri(address DGAddr, string memory baseUri) public onlyOwner {
        // IDeedGrain DG = IDeedGrain(DGAddr);
        // DG.setBaseUri(baseUri);
        assembly{
            let calld := mload(0x20)
            mstore(calld, 0xa0bcfc7f) // Keccak256("setBaseUri(string)")
            mstore(add(calld, 0x20), baseUri)
            calld := add(calld, 0x1c)
            pop(call(gas(), DGAddr, 0, calld, 0x40, 0, 0x20))
        }
    }

    /// @dev Only issuer can airdrop the nft
    /// @param DGAddr DG contract address
    /// @param tokenId TokenId
    /// @param addrs All the users address to airdrop
    function mintDGV1(address DGAddr, uint tokenId, address[] memory addrs) public {
        assembly{
            let ptr := mload(0x20)
            mstore(ptr, DGAddr)
            mstore(add(ptr, 0x20), deedGrainAddrToIssuer.slot)
        // require(msg.sender == dgMinter || msg.sender == deedGrainAddrToIssuer[DGAddr], "caller are not allowed to mint");
            if iszero(or(eq(sload(dgMinter.slot), caller()), eq(sload(keccak256(ptr, 0x40)), caller()))){
                let err := mload(0x20)
                mstore(err, Error_Selector)
                mstore(add(err, 0x20), 0x20)  // string offset
                mstore(add(err, 0x40), InsufficientPermission_Err_Length)
                mstore(add(err, 0x60), InsufficientPermission_Err_Message)
                revert(add(err, 0x1c), sub(0x80, 0x1c))
            }
        // IDeedGrainV1 DG = IDeedGrainV1(DGAddr);
        // for (uint i = 0; i < addrs.length; i++) {
        //    DG.mint(addrs[i], tokenId);
        // }
            let addrsLen := mload(addrs)
            for {let i := 0} lt(i, addrsLen){i := add(i, 1)} {
                let addr := mload(add(addrs, mul(0x20, add(i, 1))))
                {
                    let calld := mload(0x40)
                    mstore(calld, 0x40c10f19) // Keccak256("mint(address,uint256)")
                    mstore(add(calld, 0x20), addr)
                    mstore(add(calld, 0x40), tokenId)
                    calld := add(calld, 0x1c)
                    pop(call(gas(), DGAddr, 0, calld, 0x60, 0, 0x20))
                }
            }
        }
    }

    /// @dev Only issuer can airdrop the nft
    /// @param DGAddr DG contract address
    /// @param tokenId TokenId
    /// @param addrs All the users address to airdrop
    function mintDGV2(
        address DGAddr,
        uint256 tokenId,
        address[] memory addrs,
        bytes memory data
    ) public {
        assembly{
            let ptr := mload(0x20)
            mstore(ptr, DGAddr)
            mstore(add(ptr, 0x20), deedGrainAddrToIssuer.slot)
        // require(msg.sender == dgMinter || msg.sender == deedGrainAddrToIssuer[DGAddr], "caller are not allowed to mint");
            if iszero(or(eq(sload(dgMinter.slot), caller()), eq(sload(keccak256(ptr, 0x40)), caller()))){
                let err := mload(0x20)
                mstore(err, Error_Selector)
                mstore(add(err, 0x20), 0x20)  // string offset
                mstore(add(err, 0x40), InsufficientPermission_Err_Length)
                mstore(add(err, 0x60), InsufficientPermission_Err_Message)
                revert(add(err, 0x1c), sub(0x80, 0x1c))
            }
        }

        // IDeedGrain DG = IDeedGrain(DGAddr);
        // for (uint256 i = 0; i < addrs.length; i++) {
        //     DG.mint(addrs[i], tokenId, data);
        // }
        for (uint256 il = 0; il < addrs.length; il++) {
            bytes memory params = abi.encode(addrs[il], tokenId, data);
            assembly{
                mstore(0x40, 0x94d008ef) // Keccak256("mint(address,uint256,bytes)")
                let paramLen := mload(params)
                for {let i := 0} lt(i, add(div(paramLen, 0x20), 1)) {i := add(i, 1)} {
                    mstore(add(0x40, mul(0x20, add(i, 1))), mload(add(params, mul(0x20, add(i, 1)))))
                }
                pop(call(gas(), DGAddr, 0, 0x40, add(paramLen, 0x04), 0, 0x20))
            }
        }
    }


    /// @dev User claim the nft
    /// @param DGAddr DG token address
    /// @param tokenId TokenId
    /// @param data Data
    /// @param evidence Signature
    function claimDG(
        address DGAddr,
        uint256 tokenId,
        bytes memory data,
        bytes memory evidence
    ) public {
        bytes32 keccakEvidence;
        assembly{
        // require(!_evidenceUsed[keccak256(_evidence)])
            let ptr := mload(0x40)
            keccakEvidence := keccak256(add(evidence, 0x20), mload(evidence))
            mstore(ptr, keccakEvidence)
            mstore(add(ptr, 0x20), _evidenceUsed.slot)
            if sload(keccak256(ptr, 0x40)){
                let err := mload(0x20)
                mstore(err, Error_Selector)
                mstore(add(err, 0x20), 0x20)  // string offset
                mstore(add(err, 0x40), InsufficientPermission_Err_Length)
                mstore(add(err, 0x60), InsufficientPermission_Err_Message)
                revert(add(err, 0x1c), sub(0x80, 0x1c))
            }
        }

        bytes32 hash = keccak256(abi.encodePacked(msg.sender, DGAddr, tokenId, data, block.chainid));

        assembly {
        // _validate(hash, _evidence, signer)
            let validate := mload(0x40)
            mstore(validate, 0x6d050b00) // Keccak256("_validate(bytes32,bytes,address)")
            mstore(add(validate, 0x20), hash)
            mstore(add(validate, 0x40), 0x60)
            mstore(add(validate, 0x60), sload(signer.slot))
            mstore(add(validate, 0x80), mload(evidence))
            mstore(add(validate, 0xa0), mload(add(evidence, 0x20)))
            mstore(add(validate, 0xc0), mload(add(evidence, 0x40)))
            mstore(add(validate, 0xe0), mload(add(evidence, 0x60)))
            let calld := add(validate, 0x1c)
            pop(staticcall(gas(), address(), calld, 0x100, 0x20, 0x20))
            if iszero(mload(0x20)) {
                let err := mload(0x20)
                mstore(err, Error_Selector)
                mstore(add(err, 0x20), 0x20)  // string offset
                mstore(add(err, 0x40), InsufficientPermission_Err_Length)
                mstore(add(err, 0x60), InsufficientPermission_Err_Message)
                revert(add(err, 0x1c), sub(0x80, 0x1c))
            }
        }

        assembly{
        // _evidenceUsed[keccak256(_evidence)] = true;
            let ptr := mload(0x40)
            mstore(ptr, keccakEvidence)
            mstore(add(ptr, 0x20), _evidenceUsed.slot)
            let evidenceUsed := keccak256(ptr, 0x40)
            sstore(evidenceUsed, 0x01)
        }

        // IDeedGrain DG = IDeedGrain(DGAddr);
        // DG.mint(msg.sender, tokenId, data);
        bytes memory params = abi.encode(msg.sender, tokenId, data);
        assembly{
            mstore(0x40, 0x94d008ef) // Keccak256("mint(address,uint256,bytes)")
            let paramLen := mload(params)
            for {let i := 0} lt(i, add(div(paramLen, 0x20), 1)) {i := add(i, 1)} {
                mstore(
                add(0x40, mul(0x20, add(i, 1))),
                mload(add(params, mul(0x20, add(i, 1))))
                )
            }
            pop(call(gas(), DGAddr, 0, 0x40, add(paramLen, 0x04), 0, 0x20))
        }
    }

    /// @dev Only issuer can set NFT supply
    /// @param NFTAddr DGNFT contract address
    /// @param supply NFT supply number
    function setNFTSupply(address NFTAddr, uint256 supply) public {
        assembly{
            let ptr := mload(0x20)
            mstore(ptr, NFTAddr)
            mstore(add(ptr, 0x20), deedGrainAddrToIssuer.slot)
        //require(msg.sender == dgMinter || msg.sender == deedGrainAddrToIssuer[DGAddr],"caller are not allowed to set supply");
            if iszero(or(eq(sload(dgMinter.slot), caller()), eq(sload(keccak256(ptr, 0x40)), caller()))){
                let err := mload(0x20)
                mstore(err, Error_Selector)
                mstore(add(err, 0x20), 0x20)  // string offset
                mstore(add(err, 0x40), InsufficientPermission_Err_Length)
                mstore(add(err, 0x60), InsufficientPermission_Err_Message)
                revert(add(err, 0x1c), sub(0x80, 0x1c))
            }

        // IDeedGrainNFT NFT = IDeedGrainNFT(NFTAddr);
        // NFT.setSupply(supply);
            let calld := add(ptr, 0x40)
            mstore(calld, 0x3b4c4b25) // Keccak256("setSupply(uint256)")
            mstore(add(calld, 0x20), supply)
            calld := add(calld, 0x1c)
            pop(call(gas(), NFTAddr, 0, calld, 0x40, 0, 0x20))
        }
    }

    /// @dev Only issuer can set NFT's baseuri
    /// @param NFTAddr DG NFT contract address
    /// @param baseUri All of the NFT's baseuri
    function setNFTBaseUri(address NFTAddr, string memory baseUri) public onlyOwner {
        assembly{
        // IDeedGrainNFT NFT = IDeedGrainNFT(NFTAddr);
        // NFT.setBaseUri(baseUri);
            let calld := mload(0x20)
            mstore(calld, 0xa0bcfc7f) // Keccak256("setBaseUri(string)")
            mstore(add(calld, 0x20), baseUri)
            calld := add(calld, 0x1c)
            pop(call(gas(), NFTAddr, 0, calld, 0x40, 0, 0x20))
        }
    }

    /// @dev Only issuer can airdrop the nft
    /// @param NFTAddr DG NFT contract address
    /// @param sid SeriesId
    /// @param addrs All the users address to airdrop
    function mintDGNFT(
        address NFTAddr,
        uint256 sid,
        address[] memory addrs
    ) public {
        assembly{
            let ptr := mload(0x20)
            mstore(ptr, NFTAddr)
            mstore(add(ptr, 0x20), deedGrainAddrToIssuer.slot)
        //require(msg.sender == dgMinter || msg.sender == deedGrainAddrToIssuer[DGAddr],"caller are not allowed to set supply");
            if iszero(or(eq(sload(dgMinter.slot), caller()), eq(sload(keccak256(ptr, 0x40)), caller()))){
                let err := mload(0x20)
                mstore(err, Error_Selector)
                mstore(add(err, 0x20), 0x20)  // string offset
                mstore(add(err, 0x40), InsufficientPermission_Err_Length)
                mstore(add(err, 0x60), InsufficientPermission_Err_Message)
                revert(add(err, 0x1c), sub(0x80, 0x1c))
            }

        // IDeedGrainNFT NFT = IDeedGrainNFT(NFTAddr);
        // for (uint256 i = 0; i < addrs.length; i++) {
        //     NFT.mint(addrs[i], sid);
        // }
            let addrsLen := mload(addrs)
            for {let i := 0} lt(i, addrsLen) {i := add(i, 1)}{
                let addr := mload(add(addrs, mul(0x20, add(i, 1))))

                let calld := mload(0x40)
                mstore(calld, 0x40c10f19) // Keccak256("mint(address,uint256)")
                mstore(add(calld, 0x20), addr)
                mstore(add(calld, 0x40), sid)
                calld := add(calld, 0x1c)
                pop(call(gas(), NFTAddr, 0, calld, 0x40, 0, 0x20))
            }
        }
    }

    /// @dev User claim the nft
    /// @param NFTAddr DG NFT address
    /// @param sid SeriesId
    /// @param evidence Signature
    function claimDGNFT(
        address NFTAddr,
        uint256 sid,
        bytes memory evidence
    ) public {
        bytes32 keccakEvidence;
        assembly{
        // require(!_evidenceUsed[keccak256(_evidence)])
            let ptr := mload(0x40)
            keccakEvidence := keccak256(add(evidence, 0x20), mload(evidence))
            mstore(ptr, keccakEvidence)
            mstore(add(ptr, 0x20), _evidenceUsed.slot)
            if sload(keccak256(ptr, 0x40)){
                let err := mload(0x20)
                mstore(err, Error_Selector)
                mstore(add(err, 0x20), 0x20)  // string offset
                mstore(add(err, 0x40), InsufficientPermission_Err_Length)
                mstore(add(err, 0x60), InsufficientPermission_Err_Message)
                revert(add(err, 0x1c), sub(0x80, 0x1c))
            }
        }

        bytes32 hash = keccak256(abi.encodePacked(msg.sender, NFTAddr, sid, block.chainid));

        assembly {
        // _validate(hash, _evidence, signer)
            let validate := mload(0x40)
            mstore(validate, 0x6d050b00) // Keccak256("_validate(bytes32,bytes,address)")
            mstore(add(validate, 0x20), hash)
            mstore(add(validate, 0x40), 0x60)
            mstore(add(validate, 0x60), sload(signer.slot))
            mstore(add(validate, 0x80), mload(evidence))
            mstore(add(validate, 0xa0), mload(add(evidence, 0x20)))
            mstore(add(validate, 0xc0), mload(add(evidence, 0x40)))
            mstore(add(validate, 0xe0), mload(add(evidence, 0x60)))
            let calld := add(validate, 0x1c)
            pop(staticcall(gas(), address(), calld, 0x100, 0x20, 0x20))
            if iszero(mload(0x20)) {
                let err := mload(0x20)
                mstore(err, Error_Selector)
                mstore(add(err, 0x20), 0x20)  // string offset
                mstore(add(err, 0x40), InsufficientPermission_Err_Length)
                mstore(add(err, 0x60), InsufficientPermission_Err_Message)
                revert(add(err, 0x1c), sub(0x80, 0x1c))
            }
        }

        assembly{
        // _evidenceUsed[keccak256(_evidence)] = true;
            let ptr := mload(0x40)
            mstore(ptr, keccakEvidence)
            mstore(add(ptr, 0x20), _evidenceUsed.slot)
            let evidenceUsed := keccak256(ptr, 0x40)
            sstore(evidenceUsed, 0x01)
        }

        // IDeedGrainNFT NFT = IDeedGrainNFT(NFTAddr);
        // NFT.mint(msg.sender, sid);
        assembly{
            let calld := mload(0x40)
            mstore(calld, 0x40c10f19) // Keccak256("mint(address,uint256)")
            mstore(add(calld, 0x20), caller())
            mstore(add(calld, 0x40), sid)
            calld := add(calld, 0x1c)
            pop(call(gas(), NFTAddr, 0, calld, 0x40, 0, 0x20))
        }

        //        require(
        //            !_evidenceUsed[keccak256(evidence)] &&
        //        _validate(
        //            keccak256(abi.encodePacked(msg.sender, NFTAddr, sid, block.chainid)),
        //            evidence,
        //            signer
        //        ),
        //            "invalid evidence"
        //        );
        //        _evidenceUsed[keccak256(evidence)] = true;
        //        IDeedGrainNFT NFT = IDeedGrainNFT(NFTAddr);
        //        NFT.mint(msg.sender, sid);
    }

    /// @dev validate signature msg
    function _validate(
        bytes32 message,
        bytes memory signature,
        address signer
    ) public view returns (bool) {
        assembly {
        // require(signer != address(0) && signature.length == 65);
            if or(eq(signer, 0x0), iszero(eq(mload(signature), 65))){
                let err := mload(0x20)
                mstore(err, Error_Selector)
                mstore(add(err, 0x20), 0x20)  // string offset
                mstore(add(err, 0x40), InvalidEvidence_Err_Length)
                mstore(add(err, 0x60), InvalidEvidence_Err_Message)
                revert(add(err, 0x1c), sub(0x80, 0x1c))
            }

        // Ensure that first word of scratch space is empty.
            mstore(0, 0)

            let r := mload(add(signature, 0x20))
            let s := mload(add(signature, 0x40))
            let v := add(byte(0, mload(add(signature, 0x60))), 27)

        // address recoveredSigner = ecrecover(message, v, r, s);
        // ecrecover is a hardcoded contract at address 0x01
            let hashWithSig := mload(0x40)
            mstore(hashWithSig, message)
            mstore(add(hashWithSig, 0x20), v)
            mstore(add(hashWithSig, 0x40), r)
            mstore(add(hashWithSig, 0x60), s)

            pop(staticcall(gas(), 0x01, hashWithSig, 0x80, 0, 0x20))

            let recoveredSigner := mload(0)
        // return signer == owner, "Invalid signature");
            mstore(0x20, eq(signer, recoveredSigner))
            return (0x20, 0x20)
        }
    }
}
