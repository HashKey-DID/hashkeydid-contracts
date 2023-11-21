// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.8.0;

import "./interfaces/IDeedGrain.sol";
import "./interfaces/IDeedGrainV1.sol";
import "./interfaces/IDeedGrainNFT.sol";
import "./interfaces/IResolver.sol";
import "./DidStorage.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

abstract contract DGIssuer is DidV2Storage {
    /// @dev Emitted when issue DG successfully
    event IssueDG(address indexed, address);

    /// @dev Emitted when issue NFT successfully
    event IssueNFT(address indexed, address);

    /// @dev Only owner
    modifier onlyOwner() {
        require(msg.sender == owner, "caller is not the owner");
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
        require( !_evidenceUsed[keccak256(_evidence)] && _validate(keccak256(abi.encode(msg.sender, _name, _symbol, _baseUri, block.chainid)), _evidence, signer), "invalid evidence");
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
        require(!_evidenceUsed[keccak256(_evidence)] && _validate(keccak256(abi.encode(msg.sender, _name, _symbol, _baseUri, block.chainid)), _evidence, signer), "invalid evidence");
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
    ) internal pure returns (bool) {
        require(signer != address(0) && signature.length == 65);

        bytes32 r;
        bytes32 s;
        uint8 v = uint8(signature[64]) + 27;
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
        }
        return ecrecover(message, v, r, s) == signer;
    }
}

/// @title A simple did contract v2
/// @notice You can use this contract to claim an DID to you
/// @dev Only contains NFT and id name mapping now
contract DidV2 is ERC721EnumerableUpgradeable, DGIssuer {

    using CountersUpgradeable for CountersUpgradeable.Counter;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    /// @dev Emitted when did add address authorization
    event AddAuth(string did, address indexed addr, address indexed operator);
    /// @dev Emitted when did cancel address authorization
    event RemoveAuth(string did, address indexed addr, address indexed operator);
    /// @dev Emitted when the owner account has changed.
    event OwnerChanged(address previousOwner, address newOwner);
    /// @dev Emitted when add KYC successfully 
    event AddKYC(uint256 tokenId, address KYCProvider, uint256 KYCId, bool status, uint256 updateTime, uint256 expireTime, bytes evidence);
    
    /// @dev Initialize only once
    /// @param _name ERC721 NFT name
    /// @param _symbol ERC721 NFT symbol
    /// @param _baseTokenURI ERC721 NFT baseTokenURI
    /// @param _owner The address of the owner, i.e. This owner is used to reserve 
    function initialize(
        string memory _name,
        string memory _symbol,
        string memory _baseTokenURI,
        address _owner
    ) public initializer {
        __ERC721_init(_name, _symbol);
        _setBaseURI(_baseTokenURI);
        owner = _owner;
    }

    /// @dev Set baseuri
    /// @param baseURI BaseUri
    function _setBaseURI(string memory baseURI) internal {
        baseURI_ = baseURI;
    }

    /// @dev Get baseuri
    function _baseURI() internal view override returns (string memory) {
        return baseURI_;
    }

    /// @dev Set did airdrop address
    /// @param minter Airdrop address
    function setDidMinterAddr(address minter) public onlyOwner {
        didMinter = minter;
    }

    /// @notice Only the owner can call the method
    /// @dev Transaction did contract ownership
    /// @param newOwner New owner
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnerChanged(owner, newOwner);
        owner = newOwner;
    }

    /// @dev One address can only claim once
    function claim(uint256 expiredTimestamp, string memory did, bytes memory evidence, string calldata avatar) public payable {
        _mintDid(msg.sender, did, expiredTimestamp, evidence, avatar);
    }

    /// @dev Mint did
    function mint(address to, uint256 expiredTimestamp, string memory did, bytes memory evidence, string calldata avatar) public {
        require(msg.sender == owner || msg.sender == didMinter, "caller is not allowed to mint did");
        _mintDid(to, did, expiredTimestamp, evidence, avatar);
    }

    function _mintDid(address to, string memory did, uint256 expiredTimestamp, bytes memory evidence, string calldata avatar) internal {
        require(expiredTimestamp >= block.timestamp, "evidence expired");
        require(!addrClaimed[to], "addr claimed");
        require(!didClaimed[did], "did used");
        require(verifyDIDFormat(did), "illegal did");
        require(_validate(keccak256(abi.encodePacked(to, block.chainid, expiredTimestamp, did, msg.value)), evidence, signer), "invalid evidence");
        addrClaimed[to] = true;
        didClaimed[did] = true;
        uint256 tokenId = uint256(keccak256(abi.encodePacked(did)));
        did2TokenId[did] = tokenId;
        tokenId2Did[tokenId] = did;

        _mint(to, tokenId);
        if (bytes(avatar).length > 0) {
            IResolver(resolver).setAvatar(tokenId, avatar);
        }
    }
    
    /// @dev Sync did
    function mintDidLZ(
        uint256 tokenId,
        address user,
        string memory did, 
        string memory avatar,
        address[] memory KYCProviders,
        uint256[] memory KYCIds,
        KYCInfo[] memory KYCInfos,
        bytes[] memory evidences) external {
        require(msg.sender == didSync || msg.sender == didMinter, "caller is not didSync");
        require(!addrClaimed[user], "addr claimed");
        require(!didClaimed[did], "did used");
        require(verifyDIDFormat(did), "illegal did");

        addrClaimed[user] = true;
        didClaimed[did] = true;
        did2TokenId[did] = tokenId;
        tokenId2Did[tokenId] = did;
        
        _mint(user, tokenId);

        
        addKYCs(tokenId, KYCProviders, KYCIds, KYCInfos, evidences);

        if (bytes(avatar).length > 0) {
            IResolver(resolver).setAvatar(tokenId, avatar);
        }
    }

    /// @dev Verify did format
    /// @param did Did name
    function verifyDIDFormat(string memory did) public pure returns (bool) {
        bytes memory bDid = bytes(did);

        // length within user [1,50] + .key [4] = [5, 54]
        if ((bDid.length < 5) || (bDid.length > 54)) {
            return false;
        }
        // allow 0-9/a-z
        for (uint256 i = 0; i < bDid.length - 4; i++) {
            uint8 c = uint8(bDid[i]);
            if (((c < 48) || (c > 122)) || ((c > 57) && (c < 97))) {
                return false;
            }
        }
        // must end with ".key"
        // 46:. 107:k, 101:e 121:y
        if (
            (uint8(bDid[bDid.length - 4]) != 46) ||
            (uint8(bDid[bDid.length - 3]) != 107) ||
            (uint8(bDid[bDid.length - 2]) != 101) ||
            (uint8(bDid[bDid.length - 1]) != 121)
        ) {
            return false;
        }
        return true;
    }

    /// @dev Did add address authorization
    /// @param tokenId Did tokenId
    /// @param addr Address to add authorization
    function addAuth(uint256 tokenId, address addr) public {
        require(msg.sender == ownerOf(tokenId), "operation forbidden");
        require(!_auths[tokenId].contains(addr), "already added");
        _auths[tokenId].add(addr);
        emit AddAuth(tokenId2Did[tokenId], addr, ownerOf(tokenId));
    }

    /// @dev Did cancel address authorization
    /// @param tokenId Did tokenId
    /// @param addr Address to cancel authorization
    function removeAuth(uint256 tokenId, address addr) public {
        require(msg.sender == ownerOf(tokenId), "operation forbidden");
        require(_auths[tokenId].contains(addr), "already removed");
        _auths[tokenId].remove(addr);
        emit RemoveAuth(tokenId2Did[tokenId], addr, ownerOf(tokenId));
    }

    /// @dev Get all authorized addresses of did
    /// @param tokenId Did tokenId
    /// @return all Authorized addresses of did
    function getAuthorizedAddrs(uint256 tokenId) public view returns (address[] memory) {
        EnumerableSetUpgradeable.AddressSet storage auths = _auths[tokenId];

        address[] memory addrs = new address[](auths.length());
        for (uint i = 0; i < auths.length(); i++) {
            addrs[i] = auths.at(i);
        }
        return addrs;
    }

    /// @dev Get the address is authorized
    /// @param tokenId Did tokenId
    /// @param addr Address to check
    /// @return if Address is authorized
    function isAddrAuthorized(uint256 tokenId, address addr) public view returns (bool) {
        return _auths[tokenId].contains(addr);
    }

    /// @dev Know Your Customer
    function addKYCs(
        uint256 tokenId,
        address[] memory KYCProviders,
        uint256[] memory KYCIds,
        KYCInfo[] memory KYCInfos,
        bytes[] memory evidences
    ) public {
        for(uint i = 0; i < KYCProviders.length; i++){
            if(_validate(keccak256(abi.encodePacked(tokenId, KYCProviders[i], KYCIds[i], KYCInfos[i].status, KYCInfos[i].updateTime, KYCInfos[i].expireTime)), evidences[i], KYCProviders[i])){
                _KYCMap[tokenId][KYCProviders[i]][KYCIds[i]] = KYCInfos[i];
                emit AddKYC(tokenId, KYCProviders[i], KYCIds[i], KYCInfos[i].status, KYCInfos[i].updateTime, KYCInfos[i].expireTime,evidences[i]);
            }
        }
    }

    /// @dev Know your customer status
    /// @param tokenId did tokenId
    /// @param KYCProvider KYC provider address
    /// @param KYCId KYC level
    function getKYCInfo(uint256 tokenId, address KYCProvider, uint256 KYCId) public view returns (bool, uint256, uint256) {
        KYCInfo storage info = _KYCMap[tokenId][KYCProvider][KYCId];
        return (info.status, info.updateTime, info.expireTime);
    }

    /// @dev disable NFT token transfer
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    )
    internal
    override
    {
        require(from == address(0), "cannot transfer");
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function withdraw() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    receive() external payable {}
}
