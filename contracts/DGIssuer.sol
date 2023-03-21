// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.8.0;

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
        assembly{
            let fmp := mload(0x20)
            // require(msg.sender == owner, "caller is not the owner");
            if iszero(eq(caller(),sload(owner.slot))) {
                mstore(fmp, 0x08c379a0)  // function selector for Error(string)
                mstore(add(fmp, 0x20), 0x20)  // string offset
                mstore(add(fmp, 0x40), 0x17)  // length("caller is not the owner") = 23 bytes -> 0x17
                mstore(add(fmp, 0x60), 0x63616C6C6572206973206E6F7420746865206F776E6572000000000000000000)  // "caller is not the owner"
                revert(add(fmp, 0x1c), sub(0x80, 0x1c))
            }
        }
        _;
    }

    /// @dev Set DG airdrop address
    /// @param minter DG airdrop address
    function setDGMinterAddr(address minter) public onlyOwner {
        dgMinter = minter;
    }

    /// @dev Set Resolver address
    /// @param _resolver Resolver address
    function setResolverAddr(address _resolver) public onlyOwner {
        resolver = _resolver;
    }

    /// @dev Set DID sync address
    /// @param _didSync DID sync address
    function setDidSync(address _didSync) public onlyOwner {
        didSync = _didSync;
    }

    /// @dev Issue DG token
    /// @param _name ERC1155 NFT name
    /// @param _symbol ERC1155 NFT symbol
    /// @param _baseUri ERC1155 NFT baseUri
    /// @param _evidence Signature by HashKeyDID
    /// @param _transferable DG transferable
    function issueDG(string memory _name, string memory _symbol, string memory _baseUri, bytes memory _evidence, bool _transferable) public {
        require( !_evidenceUsed[keccak256(_evidence)] && _validate(keccak256(abi.encodePacked(msg.sender, _name, _symbol, _baseUri, block.chainid)), _evidence, signer), "invalid evidence");
        _evidenceUsed[keccak256(_evidence)] = true;
        bool success;
        bytes memory data;
        (success, data) = dgFactory.delegatecall(
            abi.encodeWithSignature(
                "issueDG(string,string,string,bool)",
                _name,
                _symbol,
                _baseUri,
                _transferable
            )
        );
        require(success, "issueDG failed");
        address DGAddr = abi.decode(data, (address));
        deedGrainAddrToIssuer[DGAddr] = msg.sender;
        emit IssueDG(msg.sender, DGAddr);
    }

    /// @dev Issue DG NFT
    /// @param _name ERC721 NFT name
    /// @param _symbol ERC721 NFT symbol
    /// @param _baseUri ERC721 NFT baseUri
    /// @param _evidence Signature by HashKeyDID
    /// @param _supply DG NFT supply
    function issueNFT(string memory _name, string memory _symbol, string memory _baseUri, bytes memory _evidence, uint256 _supply) public {
        require(!_evidenceUsed[keccak256(_evidence)] && _validate(keccak256(abi.encodePacked(msg.sender, _name, _symbol, _baseUri, block.chainid)), _evidence, signer), "invalid evidence");
        _evidenceUsed[keccak256(_evidence)] = true;
        bool success;
        bytes memory data;
        (success, data) = dgFactory.delegatecall(
            abi.encodeWithSignature(
                "issueNFT(string,string,string,uint256)",
                _name,
                _symbol,
                _baseUri,
                _supply
            )
        );
        require(success, "issueDGNFT failed");
        address DGNFTAddr = abi.decode(data, (address));
        deedGrainAddrToIssuer[DGNFTAddr] = msg.sender;
        emit IssueNFT(msg.sender, DGNFTAddr);
    }

    /// @dev Set didSigner address
    /// @param signer_ Did singer address
    function setSigner(address signer_) public onlyOwner {
        signer = signer_;
    }

    /// @dev Set dgFactory address
    /// @param factory DeedGrainFactory contract address
    function setDGFactory(address factory) public onlyOwner {
        dgFactory = factory;
    }

    /// @dev Only issuer can set every kind of token's supply
    /// @param DGAddr DG contract address
    /// @param tokenId TokenId
    /// @param supply Token's supply number
    function setTokenSupply(
        address DGAddr,
        uint256 tokenId,
        uint256 supply
    ) public {
        require(
            msg.sender == dgMinter || msg.sender == deedGrainAddrToIssuer[DGAddr],
            "caller are not allowed to set supply"
        );
        IDeedGrain DG = IDeedGrain(DGAddr);
        DG.setSupply(tokenId, supply);
    }

    /// @dev Only issuer can set token's baseuri
    /// @param DGAddr DG contract address
    /// @param baseUri All of the token's baseuri
    function setTokenBaseUri(address DGAddr, string memory baseUri)
    public
    onlyOwner
    {
        IDeedGrain DG = IDeedGrain(DGAddr);
        DG.setBaseUri(baseUri);
    }

    /// @dev Only issuer can airdrop the nft
    /// @param DGAddr DG contract address
    /// @param tokenId TokenId
    /// @param addrs All the users address to airdrop
    function mintDGV1(address DGAddr, uint tokenId, address[] memory addrs) public {
        require(msg.sender == dgMinter || msg.sender == deedGrainAddrToIssuer[DGAddr], "caller are not allowed to mint");
        IDeedGrainV1 DG = IDeedGrainV1(DGAddr);
        for(uint i=0; i<addrs.length; i++){
            DG.mint(addrs[i], tokenId);
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
        require(
            msg.sender == dgMinter ||
            msg.sender == deedGrainAddrToIssuer[DGAddr],
            "caller are not allowed to mint"
        );
        IDeedGrain DG = IDeedGrain(DGAddr);
        for (uint256 i = 0; i < addrs.length; i++) {
            DG.mint(addrs[i], tokenId, data);
        }
    }

    /// @dev User claim the nft
    /// @param DGAddr DG token address
    /// @param tokenId TokenId
    /// @param evidence Signature
    function claimDG(
        address DGAddr,
        uint256 tokenId,
        bytes memory data,
        bytes memory evidence
    ) public {
        require(
            !_evidenceUsed[keccak256(evidence)] &&
        _validate(
            keccak256(abi.encodePacked(msg.sender, DGAddr, tokenId, data, block.chainid)),
            evidence,
            signer
        ),
            "invalid evidence"
        );
        _evidenceUsed[keccak256(evidence)] = true;
        IDeedGrain DG = IDeedGrain(DGAddr);
        DG.mint(msg.sender, tokenId, data);
    }

    /// @dev Only issuer can set NFT supply
    /// @param NFTAddr DGNFT contract address
    /// @param supply NFT supply number
    function setNFTSupply(address NFTAddr, uint256 supply) public {
        require(
            msg.sender == dgMinter || msg.sender == deedGrainAddrToIssuer[NFTAddr],
            "caller are not allowed to set supply"
        );
        IDeedGrainNFT NFT = IDeedGrainNFT(NFTAddr);
        NFT.setSupply(supply);
    }

    /// @dev Only issuer can set NFT's baseuri
    /// @param NFTAddr DG NFT contract address
    /// @param baseUri All of the NFT's baseuri
    function setNFTBaseUri(address NFTAddr, string memory baseUri)
    public
    onlyOwner
    {
        IDeedGrainNFT NFT = IDeedGrainNFT(NFTAddr);
        NFT.setBaseUri(baseUri);
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
        require(
            msg.sender == dgMinter ||
            msg.sender == deedGrainAddrToIssuer[NFTAddr],
            "caller are not allowed to mint"
        );
        IDeedGrainNFT NFT = IDeedGrainNFT(NFTAddr);
        for (uint256 i = 0; i < addrs.length; i++) {
            NFT.mint(addrs[i], sid);
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
        require(
            !_evidenceUsed[keccak256(evidence)] &&
        _validate(
            keccak256(abi.encodePacked(msg.sender, NFTAddr, sid, block.chainid)),
            evidence,
            signer
        ),
            "invalid evidence"
        );
        _evidenceUsed[keccak256(evidence)] = true;
        IDeedGrainNFT NFT = IDeedGrainNFT(NFTAddr);
        NFT.mint(msg.sender, sid);
    }

    /// @dev validate signature msg
    function _validate(
        bytes32 message,
        bytes memory signature,
        address signer
    ) public pure returns (bool) {
        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            // require(signer != address(0) && signature.length == 65);
            if or(eq(signer,0x0),iszero(eq(mload(signature),65))){
                revert(0,0)
            }

            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := add(byte(0, mload(add(signature, 0x60))),27)
        }
        return ecrecover(message, v, r, s) == signer;
    }
}
