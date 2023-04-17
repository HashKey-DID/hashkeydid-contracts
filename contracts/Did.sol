// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.8.0;

import "./lib/ErrorAndEventConstants.sol";
import "./interfaces/IResolver.sol";
import "./DGIssuer.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

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
        // didMinter = minter;
        assembly{
            sstore(didMinter.slot, minter)
        }
    }

    /// @notice Only the owner can call the method
    /// @dev Transaction did contract ownership
    /// @param newOwner New owner
    function transferOwnership(address newOwner) public onlyOwner {
        //        require(newOwner != address(0), "Ownable: new owner is the zero address");
        //        emit OwnerChanged(owner, newOwner);
        //        owner = newOwner;
        assembly{
            if iszero(newOwner) {
                revert(0, 0) //TODO
            }

            let o := mload(0x20)
            mstore(o, sload(owner.slot))
            mstore(add(o, 0x20), newOwner)
            log1(o, 0x40, 0xb532073b38c83145e3e5135377a08bf9aab55bc0fd7c1179cd4fb995d2a5159c)

            sstore(owner.slot, newOwner)
        }
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
        assembly{
        // require(expiredTimestamp >= block.timestamp, "evidence expired");
            if lt(expiredTimestamp, timestamp()){
                let err := mload(0x20)
                mstore(err, Error_Selector)
                mstore(add(err, 0x20), 0x20)  // string offset
                mstore(add(err, 0x40), InvalidEvidence_Err_Length)
                mstore(add(err, 0x60), InvalidEvidence_Err_Message)
                revert(add(err, 0x1c), sub(0x80, 0x1c))
            }

        // require(this.balanceOf(to) == 0, "addr claimed");
            let b := mload(0x40)
            mstore(b, 0x70a08231)
            mstore(add(b, 0x20), to)
            let res := mload(0x20)
            pop(call(gas(), address(), 0, add(b, 0x1c), sub(0x40, 0x1c), res, 0x20))
            if gt(mload(res), 0x00){
                mstore(0, Error_Selector)
                mstore(0x20, 0x20)
                mstore(0x40, RegisteredAddress_Err_Message)
                mstore(0x60, RegisteredAddress_Err_Length)
                revert(0x1c, 0x64)
            }
        }
        verifyDIDFormat(did);
        require(did2TokenId[did] == 0, "did used");
        _validate(keccak256(abi.encodePacked(to, block.chainid, expiredTimestamp, did, msg.value)), evidence, signer);

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
        assembly{
        // require(this.balanceOf(to) == 0, "addr claimed");
            let b := mload(0x40)
            mstore(b, 0x70a08231)
            mstore(add(b, 0x20), user)
            let res := mload(0x20)
            pop(call(gas(), address(), 0, add(b, 0x1c), sub(0x40, 0x1c), res, 0x20))
            if gt(mload(res), 0x00){
                mstore(0, Error_Selector)
                mstore(0x20, 0x20)
                mstore(0x40, RegisteredAddress_Err_Message)
                mstore(0x60, RegisteredAddress_Err_Length)
                revert(0x1c, 0x64)
            }
        }
        verifyDIDFormat(did);
        require(did2TokenId[did] == 0, "did used");
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
    function verifyDIDFormat(string memory did) public pure returns (bool res) {
        assembly{
        // length within user [1,50] + .key [4] = [5, 54]
            let didLength := mload(did)
        // if ((bDid.length < 5) || (bDid.length > 54)) {
        //     return false;
        // }
            if or(lt(didLength, 0x05), gt(didLength, 0x36)){
                let err := mload(0x20)
                mstore(err, Error_Selector)
                mstore(add(err, 0x20), 0x20)  // string offset
                mstore(add(err, 0x40), IllegalDIDName_Err_Length)
                mstore(add(err, 0x60), IllegalDIDName_Err_Message)
                revert(add(err, 0x1c), sub(0x80, 0x1c))
            }

        // // allow 0-9/a-z
        // for (uint256 i = 0; i < bDid.length - 4; i++) {
        //     uint8 c = uint8(bDid[i]);
        //     if (((c < 48) || (c > 122)) || ((c > 57) && (c < 97))) {
        //         return false;
        //     }
        // }
            let i := 0
            let d := mload(add(did, 0x20))
            for {} lt(i, sub(didLength, 4)){i := add(i, 1)}
            {
                let t := byte(i, d)
                if or(
                or(lt(t, 0x30), gt(t, 0x7a)),
                and(gt(t, 0x39), lt(t, 0x61))
                ){
                    let err := mload(0x20)
                    mstore(err, Error_Selector)
                    mstore(add(err, 0x20), 0x20)  // string offset
                    mstore(add(err, 0x40), IllegalDIDName_Err_Length)
                    mstore(add(err, 0x60), IllegalDIDName_Err_Message)
                    revert(add(err, 0x1c), sub(0x80, 0x1c))
                }
            }

        // // must end with ".key"
        // // 46:. 107:k, 101:e 121:y
        // if !(
        //     (uint8(bDid[bDid.length - 4]) != 46) ||
        //     (uint8(bDid[bDid.length - 3]) != 107) ||
        //     (uint8(bDid[bDid.length - 2]) != 101) ||
        //     (uint8(bDid[bDid.length - 1]) != 121)
        // ) {
        //     return true;
        // }
            let endkey := mload(add(add(did, 0x20), i))
            if iszero(eq(endkey, 0x2e6b657900000000000000000000000000000000000000000000000000000000)){
                let err := mload(0x20)
                mstore(err, Error_Selector)
                mstore(add(err, 0x20), 0x20)  // string offset
                mstore(add(err, 0x40), IllegalDIDName_Err_Length)
                mstore(add(err, 0x60), IllegalDIDName_Err_Message)
                revert(add(err, 0x1c), sub(0x80, 0x1c))
            }
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
        uint256 tokenId
    )
    override
    internal
    {
        require(from == address(0), "cannot transfer");
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function withdraw() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    receive() external payable {}
}
