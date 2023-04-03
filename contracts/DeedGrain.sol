// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract DeedGrain is ERC1155 {

    string public name;
    string public symbol;

    address public controller;
    address public issuer;

    bool public transferable;
    mapping(uint256 => uint256) public totalSupply;
    mapping(uint256 => mapping(address => uint256)) public indexMap;
    mapping(uint256 => uint256) public supplies;

    modifier onlyControllers() {
        // require(msg.sender == issuer || msg.sender == controller);
        assembly{
            if iszero(or(eq(caller(), sload(issuer.slot)), eq(caller(), sload(controller.slot)))){
                revert(0, 0)// TODO
            }
        }
        _;
    }

    constructor(string memory _name, string memory _symbol, string memory _uri, bool _transferable) ERC1155(_uri){
        name = _name;
        symbol = _symbol;
        transferable = _transferable;
        controller = msg.sender;
        issuer = tx.origin;
    }

    function mint(address to, uint256 tokenId, bytes memory data) public onlyControllers {
        require(totalSupply[tokenId] + 1 <= supplies[tokenId], "insufficient supply");
        _mint(to, tokenId, 1, data);
    }

    function burn(address from, uint256 tokenId) public onlyControllers {
        _burn(from, tokenId, 1);
    }

    function reverseTransferable() public onlyControllers {
        transferable = !transferable;
    }

    function setSupply(uint256 tokenId, uint256 supply) public onlyControllers {
        supplies[tokenId] = supply;
    }

    function setBaseUri(string memory baseUri) public {
        require(msg.sender == controller);
        _setURI(baseUri);
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
        if (to == address(0)) {
            for (uint256 i = 0; i < ids.length; ++i) {
                uint256 id = ids[i];
                uint256 supply = totalSupply[id];
                require(supply >= 1, "ERC1155: burn amount exceeds totalSupply");
                unchecked {
                    totalSupply[id] = supply - 1;
                }
            }
        } else {
            for (uint256 i = 0; i < ids.length; i++) {
                uint256 id = ids[i];
                require(indexMap[id][to] == 0, "destination already got this DeedGrain");
                if (from == address(0)) {
                    uint256 next = totalSupply[id] + 1;
                    indexMap[id][to] = next;
                    totalSupply[id] = next;
                } else {
                    indexMap[id][to] = indexMap[id][from];
                    delete indexMap[id][from];
                }
            }
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
