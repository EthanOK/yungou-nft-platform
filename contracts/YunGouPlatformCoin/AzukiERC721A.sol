// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "erc721a/contracts/extensions/ERC721AQueryable.sol";

contract Azuki is ERC721AQueryable, AccessControl {
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // Total Publish Number
    uint256 private constant _TOTAL_PUBLISH_NUMBER = 30000;

    // Blind Box State
    bool private _isBlindBox;

    string private __baseURI;

    constructor(
        bool isBlindBox_,
        string memory baseURI_
    ) ERC721A("Azuki", "AZUKI") {
        _updateBaseURI(isBlindBox_, baseURI_);

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _setupRole(OWNER_ROLE, _msgSender());

        _setupRole(OPERATOR_ROLE, _msgSender());
    }

    function updateBaseURI(
        bool isBlindBox_,
        string memory baseURI_
    ) external onlyRole(OWNER_ROLE) {
        _updateBaseURI(isBlindBox_, baseURI_);
    }

    function safeMint(
        address to,
        uint256 quantity
    ) external payable checkQuantity(quantity) {
        _safeMint(to, quantity);
    }

    function mint(
        address to,
        uint256 quantity
    ) external payable checkQuantity(quantity) {
        _mint(to, quantity);
    }

    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }

    function tokenURI(
        uint256 tokenId
    ) public view virtual override(ERC721A, IERC721A) returns (string memory) {
        if (!_exists(tokenId)) _revert(URIQueryForNonexistentToken.selector);

        string memory baseURI = _baseURI();

        if (_isBlindBox) {
            return bytes(baseURI).length != 0 ? baseURI : "";
        } else {
            return
                bytes(baseURI).length != 0
                    ? string(abi.encodePacked(baseURI, _toString(tokenId)))
                    : "";
        }
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return __baseURI;
    }

    function _updateBaseURI(bool isBlindBox_, string memory baseURI_) internal {
        _isBlindBox = isBlindBox_;

        __baseURI = baseURI_;
    }

    modifier checkQuantity(uint256 quantity) {
        require(
            totalSupply() + quantity <= _TOTAL_PUBLISH_NUMBER,
            "Exceed Max Number"
        );
        _;
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(ERC721A, AccessControl, IERC721A)
        returns (bool)
    {
        return
            ERC721A.supportsInterface(interfaceId) ||
            AccessControl.supportsInterface(interfaceId) ||
            super.supportsInterface(interfaceId);
    }
}
