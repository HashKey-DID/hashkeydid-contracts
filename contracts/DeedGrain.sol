// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

contract DeedGrain is ERC1155Supply {

    string public name;
    string public symbol;

    address public controller;
    address public issuer;

    bool public transferable;
    mapping(uint256 => mapping(address => uint256)) public indexMap;
    mapping(uint256 => uint256) public supplies;

    string private _baseMetadataURI;

    modifier onlyControllers() {
        require(msg.sender == issuer || msg.sender == controller);
        _;
    }

    constructor(string memory _name, string memory _symbol, string memory _uri, bool _transferable) ERC1155(""){
        name = _name;
        symbol = _symbol;
        transferable = _transferable;
        controller = msg.sender;
        issuer = tx.origin;
        setBaseUri(_uri);
    }

    function mint(address to, uint256 tokenId) public onlyControllers {
        if (supplies[tokenId] != 0) {
            require(totalSupply(tokenId) + 1 <= supplies[tokenId], "insufficient supply");
        }
        indexMap[tokenId][to] = totalSupply(tokenId) + 1;
        _mint(to, tokenId, 1, "");
    }

    function burn(address from, uint256 tokenId, uint256 amount) public onlyControllers {
        _burn(from, tokenId, amount);
    }

    function reverseTransferable() public onlyControllers {
        transferable = !transferable;
    }

    function setSupply(uint256 tokenId, uint256 supply) public onlyControllers {
        supplies[tokenId] = supply;
    }

    function setBaseUri(string memory baseUri) public {
        require(msg.sender == controller);
        _baseMetadataURI = baseUri;
    }

    function uri(uint256 tokenId) public override view returns(string memory) {
        if (tokenId == 0) {
            return "0";
        }
        uint256 temp = tokenId;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (tokenId != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(tokenId % 10)));
            tokenId /= 10;
        }
        return string(abi.encodePacked(_baseMetadataURI, string(buffer)));
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override {
        if (!transferable) {
            require(from == address(0) || to == address(0), "this NFT is not allowed to be transferred");
        }
        for (uint i = 0; i < ids.length; i++) {
            if (to != address(0)) {
                require(balanceOf(to, ids[i]) == 0, "destination already got this DeedGrain");
                if (indexMap[ids[i]][to] == 0) {
                    uint index = indexMap[ids[i]][from];
                    indexMap[ids[i]][to] = index;
                }
            }
            delete indexMap[ids[i]][from];
        }
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}