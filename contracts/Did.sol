// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "./DeedGrain.sol";
import "./DidStorage.sol";

abstract contract DGIssuer is DidV1Storage {

    /// @dev Emitted when issue DG successfully
    event IssueDG(address indexed, address);

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

    /// @dev Issue DG token
    /// @param _name ERC1155 NFT name
    /// @param _symbol ERC1155 NFT symbol
    /// @param _baseUri ERC1155 NFT baseUri
    /// @param _evidence Signature by HashKeyDID
    /// @param _transferable DG transferable
    function issueDG(string memory _name, string memory _symbol, string memory _baseUri, bytes memory _evidence, bool _transferable) public {
        require(_validate(keccak256(abi.encodePacked(msg.sender)), _evidence, signer_), "invalid evidence");
        DeedGrain DG = new DeedGrain(_name, _symbol, _baseUri, _transferable);
        deedGrainAddrToIssur[address(DG)] = msg.sender;
        emit IssueDG(msg.sender, address(DG));
    }

    /// @dev Set didSigner address
    /// @param signer Did singer address
    function setSigner(address signer) public onlyOwner {
        signer_ = signer;
    }

    /// @dev Only issuer can set every kind of token's supply
    /// @param DGAddr DG contract address
    /// @param tokenId TokenId
    /// @param supply Token's supply number
    function setTokenSupply(address DGAddr, uint tokenId, uint supply) public {
        require(msg.sender == owner || msg.sender == deedGrainAddrToIssur[DGAddr], "caller are not allowed to set supply");
        DeedGrain DG = DeedGrain(DGAddr);
        DG.setSupply(tokenId, supply);
    }

    /// @dev Only issuer can set token's baseuri
    /// @param DGAddr DG contract address
    /// @param baseUri All of the token's baseuri
    function setTokenBaseUri(address DGAddr, string memory baseUri) public onlyOwner {
        DeedGrain DG = DeedGrain(DGAddr);
        DG.setBaseUri(baseUri);
    }

    /// @dev Only issuer can airdrop the nft
    /// @param DGAddr DG contract address
    /// @param tokenId TokenId
    /// @param addrs All the users address to airdrop
    function mintDG(address DGAddr, uint tokenId, address[] memory addrs) public {
        require(msg.sender == dgMinter || msg.sender == deedGrainAddrToIssur[DGAddr], "caller are not allowed to mint");
        DeedGrain DG = DeedGrain(DGAddr);
        for(uint i=0; i<addrs.length; i++){
            DG.mint(addrs[i], tokenId);
        }
    }

    /// @dev User claim the nft
    /// @param DGAddr DG token address
    /// @param tokenId TokenId
    /// @param evidence Signature
    function claimDG(address DGAddr, uint tokenId, bytes memory evidence) public {
        require(!_evidenceUsed[keccak256(evidence)] && _validate(keccak256(abi.encodePacked(msg.sender, DGAddr, tokenId)), evidence, signer_), "invalid evidence");
        _evidenceUsed[keccak256(evidence)] = true;
        DeedGrain DG = DeedGrain(DGAddr);
        DG.mint(msg.sender, tokenId);
    }

    /// @dev validate signature msg
    function _validate(bytes32 message, bytes memory signature, address signer_) internal pure returns (bool) {
        require(signer_ != address(0) && signature.length == 65);

        bytes32 r;
        bytes32 s;
        uint8 v = uint8(signature[64]) + 27;
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
        }
        return ecrecover(message, v, r, s) == signer_;
    }
}

/// @title A simple did contract v1
/// @notice You can use this contract to claim an DID to you
/// @dev Only contains NFT and id name mapping now
contract DidV1 is ERC721EnumerableUpgradeable, DGIssuer {

    using CountersUpgradeable for CountersUpgradeable.Counter;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    /// @dev Emitted when did claimed successfully 
    event Claim(address indexed addr, string did, uint256 indexed tokenId);
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
    )
    public
    initializer
    {
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

    /// @notice Claim did
    /// @dev One address can only claim once
    /// @param did Did
    function claim(string memory did) public {
        _mintDid(msg.sender, did);
        emit Claim(msg.sender, did, totalSupply());
    }

    /// @dev Mint did
    /// @param to Owner of did
    /// @param did Did name 
    function mint(address to, string memory did) public {
        require(msg.sender == owner || msg.sender == didMinter, "caller is not allowed to mint did");
        _mintDid(to, did);
    }

    /// @dev Mint did
    /// @param to Owner of did
    /// @param did Did name
    function _mintDid(address to, string memory did) internal {
        require(!addrClaimed[to], "addr claimed");
        require(!didClaimed[did], "did used");
        require(verifyDIDFormat(did), "illegal did");

        addrClaimed[to] = true;
        didClaimed[did] = true;
        uint256 tokenId = totalSupply()+1;
        did2TokenId[did] = tokenId;
        tokenId2Did[tokenId] = did;

        _mint(to, tokenId);
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
    /// @param tokenId user tokenId
    /// @param KYCProvider KYC provider address
    /// @param KYCId KYC level
    /// @param status bool
    /// @param updateTime Update time
    /// @param evidence Signature
    function addKYC(
        uint256 tokenId,
        address KYCProvider,
        uint256 KYCId,
        bool status,
        uint256 updateTime,
        uint256 expireTime,
        bytes memory evidence
    ) public {
        require(_validate(keccak256(abi.encodePacked(tokenId, KYCProvider, KYCId, status, updateTime, expireTime)), evidence, KYCProvider), "invalid evidence");
        _KYCMap[tokenId][KYCProvider][KYCId] = KYCInfo({status: status, updateTime: updateTime, expireTime:expireTime});
        emit AddKYC(tokenId, KYCProvider, KYCId, status, updateTime, expireTime, evidence);
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
}