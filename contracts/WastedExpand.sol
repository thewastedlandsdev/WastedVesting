//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./lib/ERC1155Upgradeable.sol";
import "./interfaces/IWastedExpand.sol";

contract WastedExpand is
    ERC1155Upgradeable,
    IWastedExpand,
    AccessControlUpgradeable
{
    using AddressUpgradeable for address;

    bytes32 public MINTER_ROLE;
    bytes32 public CONTROLLER_ROLE;
    bytes32 public OPERATOR_ROLE;

    // Mapping from item to its information.
    WastedItem[] private _items;

    function initialize(string memory _uri) public initializer {
        __ERC1155_init(_uri);
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        MINTER_ROLE = keccak256("MINTER_ROLE");
        CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
        OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    }

    function setURI(string memory uri) external onlyRole(CONTROLLER_ROLE) {
        _setURI(uri);
    }

    function createWastedItem(string memory name, ItemType itemType)
        external
        override
        onlyRole(CONTROLLER_ROLE)
    {
        _items.push(WastedItem(itemType, name, 0, 0));
        uint256 itemId = _items.length - 1;

        emit ItemCreated(itemId, name, itemType);
    }

    function claim(
        address account,
        uint256[] memory itemIds,
        uint16[] memory amount
    ) public override onlyRole(MINTER_ROLE) {
        for (uint256 i = 0; i < itemIds.length; i++) {
            _claim(account, itemIds[i], amount[i]);
        }
    }

    function _claim(
        address account,
        uint256 itemId,
        uint16 amount
    ) private {
        WastedItem storage item = _items[itemId];

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

    function transferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external {
        require(from != address(0), "WAE: invalid address");
        _safeTransferFrom(from, to, id, amount, data);
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

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
