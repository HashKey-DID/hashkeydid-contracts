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

    modifier onlyControllers() {
        require(msg.sender == issuer || msg.sender == controller);
        _;
    }

    constructor(string memory _name, string memory _symbol, string memory _uri, bool _transferable, address _issuer) ERC1155(_uri){
        name = _name;
        symbol = _symbol;
        transferable = _transferable;
        controller = msg.sender;
        issuer = _issuer;
    }

    function mint(address to, uint256 tokenId, bytes memory data) public onlyControllers {
        if (supplies[tokenId] != 0) {
            require(totalSupply(tokenId) + 1 <= supplies[tokenId], "insufficient supply");
        }
        indexMap[tokenId][to] = totalSupply(tokenId) + 1;
        _mint(to, tokenId, 1, data);
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

    function setBaseUri(string memory newuri) public {
        require(msg.sender == controller);
        super._setURI(newuri);
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        return string(abi.encodePacked(super.uri(tokenId), _uint2str(tokenId)));
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override {
        require(transferable || from == address(0) || to == address(0), "this NFT is not allowed to be transferred");
        for (uint256 i = 0; i < ids.length; i++) {
            if (to != address(0)) {
                require(balanceOf(to, ids[i]) == 0, "destination already got this DeedGrain");
                if (indexMap[ids[i]][to] == 0) {
                    uint256 index = indexMap[ids[i]][from];
                    indexMap[ids[i]][to] = index;
                }
            }
            delete indexMap[ids[i]][from];
        }
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
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
