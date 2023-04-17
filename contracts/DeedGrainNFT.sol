// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract DeedGrainNFT is ERC721 {
    event ControllerAdded(address indexed newController);
    event ControllerRemoved(address indexed oldController);

    modifier onlyControllers() {
        require(msg.sender == issuer || msg.sender == controller);
        _;
    }

    string private _baseMetadataURI;
    uint256 public totalSupply;
    uint256 public supply;
    address public controller;
    address public issuer;
    // tokenId to series id.
    mapping(uint256 => uint256) public sids;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _uri,
        uint256 _supply
    ) ERC721(_name, _symbol) {
        controller = msg.sender;
        issuer = tx.origin;
        supply = _supply;
        _baseMetadataURI = _uri;
    }

    function mint(address to, uint256 sid)
        public
        onlyControllers
        returns (uint256)
    {
        if (supply != 0) {
            require(totalSupply + 1 <= supply, "insufficient supply");
        }
        totalSupply++;
        uint256 tokenId = totalSupply;

        _mint(to, tokenId);
        sids[tokenId] = sid;
        return tokenId;
    }

    function mintBatch(
        address[] calldata addrs,
        uint256[] calldata seriesIds
    ) external onlyControllers {
        require(addrs.length == seriesIds.length, "accounts length not equal to sidArr length");
        if (supply != 0) {
            require(totalSupply + addrs.length <= supply, "insufficient supply");
        }
        for (uint256 i = 0; i < addrs.length; i++) {
            totalSupply++;
            uint256 tokenId = totalSupply;
            _mint(addrs[i], tokenId);
            sids[tokenId] = seriesIds[i];
        }
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
        supply = supply_;
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
