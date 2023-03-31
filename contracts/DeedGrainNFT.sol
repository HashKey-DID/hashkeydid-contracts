// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract DeedGrainNFT is ERC721 {
    string private _baseMetadataURI;
    uint256 public totalSupply;
    uint256 public supply;
    address public controller;
    address public issuer;
    // tokenId to series id.
    mapping(uint256 => uint256) public sids;

    modifier onlyControllers() {
        // require(msg.sender == issuer || msg.sender == controller);
        assembly{
            if iszero(or(eq(caller(), sload(issuer.slot)), eq(caller(), sload(controller.slot)))){
                revert(0, 0) //TODO
            }
        }
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _uri,
        uint256 _supply
    ) ERC721(_name, _symbol) {
        assembly{
        // controller = msg.sender;
        // issuer = tx.origin;
        // supply = _supply;
            sstore(controller.slot, caller())
            sstore(issuer.slot, origin())
            sstore(supply.slot, _supply)
        }

        _baseMetadataURI = _uri;
    }

    function mint(address to, uint256 sid)
    public
    onlyControllers
    returns (uint256)
    {
        uint256 tokenId;
        assembly{
        // require(totalSupply + 1 <= supply, "insufficient supply");
        // totalSupply++;
        // uint256 tokenId = totalSupply;
        // sids[tokenId] = sid;
            tokenId := add(sload(totalSupply.slot), 1)
            if gt(tokenId, sload(supply.slot)){
                revert(0, 0) //TODO
            }
            sstore(totalSupply.slot, tokenId)

            let s := mload(0x40)
            mstore(s, tokenId)
            mstore(add(s, 0x20), tokenId)
            sstore(keccak256(s, 0x40), sid)
        }
        _mint(to, tokenId);
        return tokenId;
    }

    function mintBatch(
        address[] calldata addrs,
        uint256[] calldata seriesIds
    ) external onlyControllers {
        uint256 len;
        assembly{
        // require(addrs.length == seriesIds.length, "accounts length not equal to sidArr length");
            len := mload(addrs.offset)
            if iszero(eq(len, mload(seriesIds.offset))){
                revert(0, 0) //TODO
            }

        // require(totalSupply + addrs.length <= supply, "insufficient supply");
            let next := add(sload(totalSupply.slot), len)
            if gt(next, sload(supply.slot)){
                revert(0, 0) //TODO
            }
        }

        for (uint256 i = 0; i < len; i++) {
            uint256 tokenId = totalSupply + i + 1;
            _mint(addrs[i], tokenId);
            sids[tokenId] = seriesIds[i];
        }
        totalSupply += len;
    }

    /**
     * Sets a new baseURI for NFT.
     */
    function setBaseUri(string memory baseUri) external {
        require(msg.sender == controller);
        _baseMetadataURI = baseUri;
    }

    /**
     * Sets totalSupply for NFT.
     */
    function setSupply(uint256 supply_) external onlyControllers {
        assembly{
        // supply = supply_;
            sstore(supply.slot, supply_)
        }
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId)
    public
    view
    virtual
    override
    returns (string memory)
    {
        require(tokenId <= totalSupply, "NFT does not exist");
        return string(abi.encodePacked(_baseMetadataURI, _uint2str(tokenId)));
    }


    function _uint2str(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bStr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bStr[k] = b1;
            _i /= 10;
        }
        return string(bStr);
    }
}
