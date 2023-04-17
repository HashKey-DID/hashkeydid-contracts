// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.8.0;

import "./DidStorage.sol";
import {
    EventIssueDG,
    EventIssueNFT
} from "./lib/ErrorAndEventConstants.sol";
import {
    _revertOwnershipMismatch,
    _revertInvalidEvidence,
    _revertDeedGrainIssueFailed,
    _revertInsufficientPermission,
    _revertZeroAddress
} from "./lib/Errors.sol";

abstract contract DGIssuer is DidV2Storage {
    /// @dev Emitted when issue DG successfully
    event IssueDG(address indexed, address);

    /// @dev Emitted when issue NFT successfully
    event IssueNFT(address indexed, address);

    /// @dev Only owner
    modifier onlyOwner() {
        if (msg.sender != owner) {
            _revertOwnershipMismatch();
        }
        _;
    }

    /// @dev Only permitted addr
    modifier onlyPermitted(address DGAddr) {
        bool permitted;
        assembly{
            let ptr := mload(0x40)
            mstore(ptr, DGAddr)
            mstore(add(ptr, 0x20), deedGrainAddrToIssuer.slot)
            //require(msg.sender == dgMinter || msg.sender == deedGrainAddrToIssuer[DGAddr]);
            if or(eq(sload(dgMinter.slot), caller()), eq(sload(keccak256(ptr, 0x40)), caller())){
                permitted := 0x01
            }
        }
        if (!permitted) {
            _revertInsufficientPermission();
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
        _validate(keccak256(abi.encodePacked(msg.sender, _name, _symbol, _baseUri, block.chainid)), _evidence, signer);
        _checkEvidence(_evidence);

        bytes memory params = abi.encodeWithSignature(
            "issueDG(string,string,string,bool)",
            _name, _symbol, _baseUri, _transferable
        );

        address DGAddr;
        assembly{
            pop(delegatecall(gas(), sload(dgFactory.slot), add(params, 0x20), mload(params), 0x00, 0x20))
            DGAddr := mload(0x00)
        }
        if (DGAddr == address(0)) {
            _revertDeedGrainIssueFailed();
        }
        assembly {
            // deedGrainAddrToIssuer[DGAddr] = msg.sender;
            let fmp := mload(0x40)
            mstore(fmp, DGAddr)
            mstore(add(fmp, 0x20), deedGrainAddrToIssuer.slot)
            sstore(keccak256(fmp, 0x40), caller())

            // emit IssueDG(msg.sender, DGAddr);
            log2(fmp, 0x20, EventIssueDG, caller())
        }
    }

    /// @dev Issue DG NFT
    /// @param _name ERC721 NFT name
    /// @param _symbol ERC721 NFT symbol
    /// @param _baseUri ERC721 NFT baseUri
    /// @param _evidence Signature by HashKeyDID
    /// @param _supply DG NFT supply
    function issueNFT(string memory _name, string memory _symbol, string memory _baseUri, bytes memory _evidence, uint256 _supply) public {
        _validate(keccak256(abi.encodePacked(msg.sender, _name, _symbol, _baseUri, block.chainid)), _evidence, signer);
        _checkEvidence(_evidence);

        bytes memory params = abi.encodeWithSignature(
            "issueNFT(string,string,string,uint256)",
            _name, _symbol, _baseUri, _supply
        );

        address DGAddr;
        assembly{
            pop(delegatecall(gas(), sload(dgFactory.slot), add(params, 0x20), mload(params), 0x00, 0x20))
            DGAddr := mload(0x00)
        }
        if (DGAddr == address(0)) {
            _revertDeedGrainIssueFailed();
        }
        
        assembly {
            // deedGrainAddrToIssuer[DGAddr] = msg.sender;
            let fmp := mload(0x40)
            mstore(fmp, DGAddr)
            mstore(add(fmp, 0x20), deedGrainAddrToIssuer.slot)
            sstore(keccak256(fmp, 0x40), caller())
            //emit IssueNFT(msg.sender, DGNFTAddr);
            log2(fmp, 0x20, EventIssueNFT, caller())
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
    function setTokenSupply(address DGAddr, uint256 tokenId, uint256 supply) public onlyPermitted(DGAddr) {
        assembly {
            // IDeedGrain DG = IDeedGrain(DGAddr);
            // DG.setSupply(tokenId, supply);
            let calld := mload(0x40)
            mstore(calld, 0xfc784d49) // Keccak256("setSupply(uint256,uint256)")
            mstore(add(calld, 0x20), tokenId)
            mstore(add(calld, 0x40), supply)
            let success := call(gas(), DGAddr, 0, add(calld, 0x1c), sub(0x60, 0x1c), 0, 0)
            if iszero(success){
                revert(0, 0)
            }
        }
    }

    /// @dev Only issuer can set token's baseuri
    /// @param DGAddr DG contract address
    /// @param baseUri All of the token's baseuri
    function setTokenBaseUri(address DGAddr, string memory baseUri) public onlyOwner {
        // IDeedGrain DG = IDeedGrain(DGAddr);
        // DG.setBaseUri(baseUri);
        bytes memory params = abi.encodeWithSignature("setBaseUri(string)", baseUri);
        assembly{
            let success := call(gas(), DGAddr, 0, add(params, 0x20), mload(params), 0, 0)
            if iszero(success){
                revert(0, 0)
            }
        }
    }

    /// @dev Only issuer can airdrop the nft
    /// @param DGAddr DG contract address
    /// @param tokenId TokenId
    /// @param addrs All the users address to airdrop
    function mintDGV1(address DGAddr, uint tokenId, address[] memory addrs) public onlyPermitted(DGAddr) {
        assembly{
        // IDeedGrainV1 DG = IDeedGrainV1(DGAddr);
        // for (uint i = 0; i < addrs.length; i++) {
        //    DG.mint(addrs[i], tokenId);
        // }
            let addrsLen := mload(addrs)
            let calld := mload(0x40)
            mstore(calld, 0x40c10f19) // Keccak256("mint(address,uint256)")
            mstore(add(calld, 0x40), tokenId)
            for {let i := 0} lt(i, addrsLen){} {
                i := add(i, 1)
                mstore(add(calld, 0x20), mload(add(addrs, mul(0x20, i))))
                let success := call(gas(), DGAddr, 0, add(calld, 0x1c), sub(0x60, 0x1c), 0, 0)
                if iszero(success){
                    revert(0, 0)
                }
            }
        }
    }

    /// @dev Only issuer can airdrop the nft
    /// @param DGAddr DG contract address
    /// @param tokenId TokenId
    /// @param addrs All the users address to airdrop
    function mintDGV2(address DGAddr, uint256 tokenId, address[] memory addrs, bytes memory data) public onlyPermitted(DGAddr) {
        // IDeedGrain DG = IDeedGrain(DGAddr);
        // for (uint256 i = 0; i < addrs.length; i++) {
        //     DG.mint(addrs[i], tokenId, data);
        // }
        bytes memory params = abi.encodeWithSignature(
            "mint(address,uint256,bytes)",
            address(0),
            tokenId,
            data
        );
        assembly{
            for {let i := 0}lt(i, mload(addrs)){}{
                i := add(i, 1)
                mstore(add(params, 0x24), mload(add(addrs, mul(0x20, i))))
                let success := call(gas(), DGAddr, 0, add(params, 0x20), mload(params), 0, 0)
                if iszero(success){
                    revert(0, 0)
                }
            }
        }
    }


    /// @dev User claim the nft
    /// @param DGAddr DG token address
    /// @param tokenId TokenId
    /// @param data Data
    /// @param evidence Signature
    function claimDG(address DGAddr, uint256 tokenId, bytes memory data, bytes memory evidence) public {
        _validate(keccak256(abi.encodePacked(msg.sender, DGAddr, tokenId, data, block.chainid)), evidence, signer);
        _checkEvidence(evidence);

        // IDeedGrain DG = IDeedGrain(DGAddr);
        // DG.mint(msg.sender, tokenId, data);
        bytes memory params = abi.encodeWithSignature("mint(address,uint256,bytes)",
            msg.sender, tokenId, data);
        assembly{
            let success := call(gas(), DGAddr, 0, add(params, 0x20), mload(params), 0, 0)
            if iszero(success){
                revert(0, 0)
            }
        }
    }

    /// @dev Only issuer can set NFT supply
    /// @param NFTAddr DGNFT contract address
    /// @param supply NFT supply number
    function setNFTSupply(address NFTAddr, uint256 supply) public onlyPermitted(NFTAddr) {
        assembly {
        // IDeedGrainNFT NFT = IDeedGrainNFT(NFTAddr);
        // NFT.setSupply(supply);
            let calld := mload(0x40)
            mstore(calld, 0x3b4c4b25) // Keccak256("setSupply(uint256)")
            mstore(add(calld, 0x20), supply)
            let success := call(gas(), NFTAddr, 0, add(calld, 0x1c), sub(0x40, 0x1c), 0, 0)
            if iszero(success){
                revert(0, 0)
            }
        }
    }

    /// @dev Only issuer can set NFT's baseuri
    /// @param NFTAddr DG NFT contract address
    /// @param baseUri All of the NFT's baseuri
    function setNFTBaseUri(address NFTAddr, string memory baseUri) public onlyOwner {
        // IDeedGrainNFT NFT = IDeedGrainNFT(NFTAddr);
        // NFT.setBaseUri(baseUri);
        bytes memory params = abi.encodeWithSignature("setBaseUri(string)", baseUri);
        assembly{
            let success := call(gas(), NFTAddr, 0, add(params, 0x20), mload(params), 0, 0)
            if iszero(success){
                revert(0, 0)
            }
        }
    }

    /// @dev Only issuer can airdrop the nft
    /// @param NFTAddr DG NFT contract address
    /// @param sid SeriesId
    /// @param addrs All the users address to airdrop
    function mintDGNFT(address NFTAddr, uint256 sid, address[] memory addrs) public onlyPermitted(NFTAddr) {
        
        // IDeedGrainNFT NFT = IDeedGrainNFT(NFTAddr);
        // for (uint256 i = 0; i < addrs.length; i++) {
        //     NFT.mint(addrs[i], sid);
        // }
        assembly{
            let calld := mload(0x40)
            mstore(calld, 0x40c10f19) // Keccak256("mint(address,uint256)")
            mstore(add(calld, 0x40), sid)
            for {let i := 0} lt(i, mload(addrs)) {}{
                i := add(i, 1)
                mstore(add(calld, 0x20), mload(add(addrs, mul(0x20, i))))
                let success := call(gas(), NFTAddr, 0, add(calld, 0x1c), sub(0x60, 0x1c), 0, 0)
                if iszero(success){
                    revert(0, 0)
                }
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
        _validate(keccak256(abi.encodePacked(msg.sender, NFTAddr, sid, block.chainid)), evidence, signer);
        _checkEvidence(evidence);

        // IDeedGrainNFT NFT = IDeedGrainNFT(NFTAddr);
        // NFT.mint(msg.sender, sid);
        assembly{
            let calld := mload(0x40)
            mstore(calld, 0x40c10f19) // Keccak256("mint(address,uint256)")
            mstore(add(calld, 0x20), caller())
            mstore(add(calld, 0x40), sid)
            let success := call(gas(), NFTAddr, 0, add(calld, 0x1c), sub(0x60, 0x1c), 0, 0)
            if iszero(success){
                revert(0, 0)
            }
        }
    }

    /// @dev validate signature msg
    function _validate(
        bytes32 message,
        bytes memory signature,
        address signer
    ) internal view returns (bool) {
        if (signer == address(0) || signature.length != 65) {
            _revertInvalidEvidence();
        }
        address recoveredSigner;
        assembly {
        // Ensure that first word of scratch space is empty.
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

            pop(staticcall(gas(), 0x01, hashWithSig, 0x80, 0x00, 0x20))
            recoveredSigner := mload(0x00)
        }
        if (recoveredSigner != signer) {
            _revertInvalidEvidence();
        }
        return true;
    }

    /// @dev check whether evidence is used and then mark evidence. 
    ///      If not, revert. 
    function _checkEvidence(bytes memory evidence) internal {
        // require(!_evidenceUsed[keccak256(evidence)])
        // _evidenceUsed[keccak256(evidence)] = true;
        bool used;
        assembly{
            let ptr := mload(0x40)
            mstore(ptr, keccak256(add(evidence, 0x20), mload(evidence)))
            mstore(add(ptr, 0x20), _evidenceUsed.slot)
            if sload(keccak256(ptr, 0x40)){
                used := 0x01
            }
            sstore(keccak256(ptr, 0x40), 0x01)
        }
        if (used) {
            _revertInvalidEvidence();
        }
    }
}
