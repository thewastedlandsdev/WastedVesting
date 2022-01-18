//SPDX-License-Identifier: MIT

import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";

pragma solidity ^0.8.0;

interface IWastedExpand is IERC1155Upgradeable {
    // Event required.
    enum ItemType {
        FRAME,
        BACKGROUND,
        TEXTURE
    } // 3 types of expand.
    event ItemCreated(uint256 indexed itemId, string name, ItemType itemType);
    event ItemClaimed(
        address indexed account,
        uint256 indexed itemId,
        uint256 indexed amount
    );

    struct WastedItem {
        ItemType itemType;
        string name;
        uint16 minted;
        uint16 burnt;
    }

    /**
     * @notice Burns ERC1155 equipment since it is equipped to the user.
     */
    function putItemsIntoStorage(address account, uint256[] memory itemIds)
        external;

    /**
     * @notice claim warrior.
     */
    function claim(
        address account,
        uint256[] memory itemIds,
        uint16[] memory amount
    ) external;

    /**
     * @notice Create an wasted item.
     */
    function createWastedItem(string memory name, ItemType itemType) external;

    /**
     * @notice Returns ERC1155 equipment back to the owner.
     */
    function returnItems(address account, uint256[] memory itemIds) external;

    /**
     * @notice Get informations of item by itemId
     */

    function getItem(uint256 itemId)
        external
        view
        returns (WastedItem memory item);

    /**
     * @notice Gets wasted item type.
     */
    function getItemType(uint256 itemId) external view returns (ItemType);

    /**
        @notice transfer func for operator contract
     */
    function transferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;
}
