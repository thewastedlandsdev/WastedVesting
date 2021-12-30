//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./lib/ERC1155.sol";
import "./interfaces/IWastedExpand.sol";

contract WastedExpand is ERC1155, IWastedExpand, AccessControl {
    using Address for address;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // Mapping from item to its information.
    WastedItem[] private _items;

    constructor(string memory _uri) ERC1155(_uri) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function setURI(string memory uri) external onlyRole(CONTROLLER_ROLE) {
        _setURI(uri);
    }

    function createWastedItem(
        string memory name,
        uint16 maxSupply,
        ItemType itemType
    ) external override onlyRole(CONTROLLER_ROLE) {
        require(maxSupply > 0, "WAE: invalid maxSupply");
        _items.push(WastedItem(itemType, name, maxSupply, 0, 0));
        uint256 itemId = _items.length - 1;

        emit ItemCreated(itemId, name, maxSupply, itemType);
    }

    function claim(
        address account,
        uint256[] memory itemIds,
        uint16[] memory amount
    ) public override onlyRole(MINTER_ROLE) {
        for(uint i = 0; i < itemIds.length; i++) {
            _claim(account, itemIds[i], amount[i]);
        }
    }

    function _claim(
        address account,
        uint256 itemId,
        uint16 amount
    ) private {
        WastedItem storage item = _items[itemId];

        require(
            item.minted + amount <= item.maxSupply,
            "WAE: max supply reached"
        );

        _balances[itemId][account] += amount;
        item.minted += amount;

        emit TransferSingle(msg.sender, address(0), account, itemId, amount);
        emit ItemClaimed(account, itemId, amount);
    }

    function putItemsIntoStorage(address account, uint256[] memory itemIds)
        external
        override
        onlyRole(OPERATOR_ROLE)
    {
        for (uint256 i = 0; i < itemIds.length; i++) {
            require(
                _balances[itemIds[i]][account] >= 1,
                "WAE: exceeds balance"
            );
            _balances[itemIds[i]][account] -= 1;
        }
    }

    function returnItems(address account, uint256[] memory itemIds)
        external
        override
        onlyRole(OPERATOR_ROLE)
    {
        for (uint256 i = 0; i < itemIds.length; i++) {
            _balances[itemIds[i]][account] += 1;
        }
    }

    function getItem(uint256 itemId)
        external
        view
        override
        returns (WastedItem memory item)
    {
        return _items[itemId];
    }

    function getItemType(uint256 itemId)
        external
        view
        override
        returns (ItemType)
    {
        return _items[itemId].itemType;
    }

    function isOutOfStock(uint256 itemId, uint16 amount)
        external
        view
        override
        returns (bool)
    {
        WastedItem memory item = _items[itemId];
        return item.minted + amount > item.maxSupply;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}