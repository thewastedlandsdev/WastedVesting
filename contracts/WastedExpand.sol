//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./lib/ERC1155.sol";
import "./interfaces/IWastedExpand.sol";
import "./utils/PermissionGroup.sol";

contract WastedExpand is ERC1155, IWastedExpand, PermissionGroup {
    using Address for address;

    // Mapping from item to its information.
    WastedItem[] private _items;

    constructor(string memory _uri) ERC1155(_uri) {}

    function setURI(string memory uri) external onlyOwner {
        _setURI(uri);
    }

    function createWastedItem(
        string memory name,
        uint16 maxSupply,
        ItemType itemType
    ) external override onlyOwner {
        require(maxSupply > 0, "WAE: invalid maxSupply");
        _items.push(WastedItem(itemType, name, maxSupply, 0, 0));
        uint256 itemId = _items.length - 1;

        emit ItemCreated(itemId, name, maxSupply, itemType);
    }

    function claim(
        address account,
        uint256 itemId,
        uint16 amount
    ) public override onlyOperator returns (bool) {
        WastedItem storage item = _items[itemId];

        require(
            item.minted + amount <= item.maxSupply,
            "WAE: max supply reached"
        );

        _balances[itemId][account] += amount;
        item.minted += amount;

        emit TransferSingle(msg.sender, address(0), account, itemId, amount);
        emit ItemClaimed(account, itemId, amount);

        return item.minted == item.maxSupply;
    }

    function putItemsIntoStorage(address account, uint256[] memory itemIds)
        external
        override
        onlyOperator
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
        onlyOperator
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
}
