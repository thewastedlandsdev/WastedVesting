//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IWastedWarrior is IERC721 {
    enum PackageRarity {
        NONE,
        PLASTIC,
        STEEL,
        GOLD,
        PLATINUM
    }

    event WarriorCreated(
        uint256 indexed warriorId,
        bool isBreed,
        bool isFusion,
        uint256 indexed packageType,
        address indexed buyer
    );
    event WarriorListed(uint256 indexed warriorId, uint256 price);
    event WarriorDelisted(uint256 indexed warriorId);
    event WarriorBought(
        uint256 indexed warriorId,
        address buyer,
        address seller,
        uint256 price
    );
    event WarriorOffered(
        uint256 indexed warriorId,
        address buyer,
        uint256 price
    );
    event WarriorOfferCanceled(uint256 indexed warriorId, address buyer);
    event NameChanged(uint256 indexed warriorId, string newName);
    event PetAdopted(uint256 indexed warriorId, uint256 indexed petId);
    event PetReleased(uint256 indexed warriorId, uint256 indexed petId);
    event ItemsEquipped(uint256 indexed warriorId, uint256[] itemIds);
    event ItemsRemoved(uint256 indexed warriorId, uint256[] itemIds);
    event WarriorLeveledUp(
        uint256 indexed warriorId,
        uint256 level,
        uint256 amount
    );
    event BreedingWarrior(
        uint256 indexed fatherId,
        uint256 indexed motherId,
        uint256 newId,
        address owner
    );
    event FusionWarrior(
        uint256 indexed firstWarriorId,
        uint256 indexed secondWarriorId,
        uint256 newId,
        address owner
    );
    event AddWarriorToBlacklist(uint256 warriorId);
    event RemoveWarriorFromBlacklist(uint256 warriorId);

    struct Collaborator {
        uint256 totalSupplyPlasticPackages;
        uint256 totalSupplySteelPackages;
        uint256 totalSupplyGoldPackages;
        uint256 totalSupplyPlatinumPackages;
        uint256 mintedPlasticPackages;
        uint256 mintedSteelPackages;
        uint256 mintedGoldPackages;
        uint256 mintedPlatinumPackages;
    }

    struct Warrior {
        string name;
        uint256 level;
        uint256 weapon;
        uint256 armor;
        uint256 accessory;
        bool isBreed;
        bool isFusion;
    }

    /**
     * @notice add collaborator info.
     *
     */
    function addCollaborator(
        address collaborator,
        uint256 totalSupplyPlasticPackages,
        uint256 totalSupplySteelPackages,
        uint256 totalSupplyGoldPackages,
        uint256 totalSupplyPlatinumPackages
    ) external;

    /**
     * @notice get collaborator info.
     *
     */
    function getInfoCollaborator(address addressCollab)
        external
        view
        returns (Collaborator memory);

    /**
     * @notice Gets warrior information.
     *
     * @dev Prep function for staking.
     */
    function getWarrior(uint256 warriorId)
        external
        view
        returns (
            string memory name,
            bool isBreed,
            bool isFusion,
            uint256 level,
            uint256 pet,
            uint256[3] memory equipment
        );

    /**
     * @notice warrior listing.
     */
    function getWarriorListing(uint256 warriorId)
        external
        view
        returns (uint256);

    /**
     * @notice warrior listing.
     */
    function getWarriorInBlacklist(uint256 warriorId)
        external
        view
        returns (bool);

    /**
     * @notice get plastic package fee.
     */
    function getPlasticPackageFee() external view returns (uint256);

    /**
     * @notice get steel package fee.
     */
    function getSteelPackageFee() external view returns (uint256);

    /**
     * @notice get gold package fee.
     */
    function getGoldPackageFee() external view returns (uint256);

    /**
     * @notice get platinum package fee.
     */
    function getPlatinumPackageFee() external view returns (uint256);

    /**
     * @notice Function can level up a Warrior.
     *
     * @dev Prep function for staking.
     */
    function levelUp(uint256 warriorId, uint256 amount) external;

    /**
     * @notice Get current level of given warrior.
     *
     * @dev Prep function for staking.
     */
    function getWarriorLevel(uint256 warriorId) external view returns (uint256);

    /**
     * @notice mint warrior for specific address.
     *
     * @dev Function take 3 arguments are address of buyer, amount, rarityPackage.
     *
     * Requirements:
     * - onlyCollaborator
     */
    function mintFor(
        address buyer,
        uint256 amount,
        uint256 rarityPackage
    ) external;

    /**
     * @notice Function to change Warrior's name.
     *
     * @dev Function take 2 arguments are warriorId, new name of warrior.
     *
     * Requirements:
     * - `replaceName` must be a valid string.
     * - `replaceName` is not duplicated.
     * - You have to pay `serviceFeeToken` to change warrior's name.
     */
    function rename(uint256 warriorId, string memory replaceName) external;

    /**
     * @notice Owner equips items to their warrior by burning ERC1155 Equipment NFTs.
     *
     * Requirements:
     * - caller must be owner of the warrior.
     */
    function equipItems(uint256 warriorId, uint256[] memory itemIds) external;

    /**
     * @notice Owner removes items from their warrior. ERC1155 Equipment NFTs are minted back to the owner.
     *
     * Requirements:
     * - Caller must be owner of the warrior.
     */
    function removeItems(uint256 warriorId, uint256[] memory itemIds) external;

    /**
     * @notice Lists a warrior on sale.
     *
     * Requirements:
     * - Caller must be the owner of the warrior.
     */
    function listing(uint256 warriorId, uint256 price) external;

    /**
     * @notice Remove from a list on sale.
     */
    function delist(uint256 warriorId) external;

    /**
     * @notice Instant buy a specific warrior on sale.
     *
     * Requirements:
     * - Caller must be the owner of the warrior.
     * - Target warrior must be currently on sale time.
     * - Sent value must be exact the same as current listing price.
     * - Owner cannot buy.
     */
    function buy(uint256 warriorId, uint256 expectedPrice) external payable;

    /**
     * @notice Gives offer for a warrior.
     *
     * Requirements:
     * - Owner cannot offer.
     */
    function offer(uint256 warriorId, uint256 offerPrice) external payable;

    /**
     * @notice Owner accept an offer to sell their warrior.
     */
    function acceptOffer(
        uint256 warriorId,
        address buyer,
        uint256 expectedPrice
    ) external;

    /**
     * @notice Abort an offer for a specific warrior.
     */
    function abortOffer(uint256 warriorId) external;

    /**
     * @notice Adopts a Pet.
     */
    function adoptPet(uint256 warriorId, uint256 petId) external;

    /**
     * @notice Abandons a Pet attached to a warrior.
     */
    function abandonPet(uint256 warriorId) external;

    /**
     * @notice Burn two warriors to create one new warrior.
     *
     * @dev Prep function for fusion
     *
     * Requirements:
     * - caller must be owner of the warriors.
     */
    function fusionWarrior(
        uint256 firstWarriorId,
        uint256 secondWarriorId,
        address owner
    ) external;

    /**
     * @notice Breed based on two warriors.
     *
     * @dev Prep function for breed
     *
     * Requirements:
     * - caller must be owner of the warriors.
     */
    function breedingWarrior(
        uint256 fatherId,
        uint256 motherId,
        address owner
    ) external;
}
