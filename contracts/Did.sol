// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.8.0;

import "./interfaces/IResolver.sol";
import "./DGIssuer.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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

    function setApprovalForAll(address operator, bool) public pure override(ERC721Upgradeable, IERC721Upgradeable) {
        require(operator == address(0));
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
    function claim(uint256 expiredTimestamp, string memory did, address token, uint256 amount, bytes memory evidence, string calldata avatar) public payable {
        if (token == address(0)) {
            amount = msg.value;
        }
        _mintDid(msg.sender, did, expiredTimestamp, token, amount, evidence, avatar);
        if (token != address(0)) {
            IERC20(token).transferFrom(msg.sender, address(this), amount);
        }
    }

    /// @dev Mint did
    function mint(address to, uint256 expiredTimestamp, string memory did, bytes memory evidence, string calldata avatar) public {
        require(msg.sender == owner || msg.sender == didMinter, "caller is not allowed to mint did");
        _mintDid(to, did, expiredTimestamp, address(0), 0, evidence, avatar);
    }

    function _mintDid(address to, string memory did, uint256 expiredTimestamp, address token, uint256 amount, bytes memory evidence, string calldata avatar) internal {
        require(expiredTimestamp >= block.timestamp, "evidence expired");
        require(balanceOf(to) == 0, "addr claimed");
        uint256 tokenId = uint256(keccak256(abi.encodePacked(did)));
        require(!_didClaimed[did] && !_exists(tokenId), "did used");
        require(verifyDIDFormat(did), "illegal did");
        require(_validate(keccak256(abi.encodePacked(to, block.chainid, expiredTimestamp, did, token, amount)), evidence, signer), "invalid evidence");
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
        require(balanceOf(user) == 0, "addr claimed");
        require(!_didClaimed[did] && !_exists(tokenId), "did used");
        require(verifyDIDFormat(did), "illegal did");

        tokenId2Did[tokenId] = did;

        _mint(user, tokenId);

        addKYCs(tokenId, KYCProviders, KYCIds, KYCInfos, evidences);

        if (bytes(avatar).length > 0) {
            IResolver(resolver).setAvatar(tokenId, avatar);
        }
    }

    function Did2TokenId(string memory did) public view returns (uint256) {
        uint256 tokenId = _did2TokenId[did];
        if (tokenId == 0) {
            tokenId = uint256(keccak256(abi.encodePacked(did)));
            require(_exists(tokenId));
        }
        return tokenId;
    }

    function DidClaimed(string memory did) public view returns (bool) {
        uint256 tokenId = uint256(keccak256(abi.encodePacked(did)));
        return _didClaimed[did] || _exists(tokenId);
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
        for (uint i = 0; i < KYCProviders.length; i++) {
            if (_validate(keccak256(abi.encodePacked(tokenId, KYCProviders[i], KYCIds[i], KYCInfos[i].status, KYCInfos[i].updateTime, KYCInfos[i].expireTime)), evidences[i], KYCProviders[i])) {
                _KYCMap[tokenId][KYCProviders[i]][KYCIds[i]] = KYCInfos[i];
                emit AddKYC(tokenId, KYCProviders[i], KYCIds[i], KYCInfos[i].status, KYCInfos[i].updateTime, KYCInfos[i].expireTime, evidences[i]);
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
        uint256 firstTokenId,
        uint256 batchSize
    )
    internal
    override
    {
        require(from == address(0), "cannot transfer");
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
    }

    function withdraw(address token) public onlyOwner {
        if (token != address(0)) {
            uint256 balance = IERC20(token).balanceOf(address(this));
            IERC20(token).transfer(msg.sender, balance);
        } else {
            payable(msg.sender).transfer(address(this).balance);
        }
    }

    receive() external payable {}
}
