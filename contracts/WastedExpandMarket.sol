pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "./interfaces/IWastedExpandCollab.sol";
import "./utils/AcceptedTokenUpgradeable.sol";
import "./interfaces/IWastedExpandMarket.sol";

contract WastedExpandMarket is
    AcceptedTokenUpgradeable,
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable,
    ERC1155HolderUpgradeable,
    IWastedExpandMarket
{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    uint256 public PERCENT;
    bytes32 public CONTROLLER_ROLE;

    IWastedExpandOperator public wastedExpand;

    uint256 public marketFeeInPercent;
    uint256 public serviceFeeInToken;
    mapping(address => mapping(uint256 => BuyInfo)) public expandsOnSale;
    mapping(address => mapping(uint256 => mapping(address => BuyInfo)))
        public expandsOffer;
    mapping(address => EnumerableSet.UintSet) private balancesOf;

    function initialize(
        IWastedExpandOperator wastedExpand_,
        uint256 marketFeeInPercent_,
        uint256 serviceFeeInToken_
    ) public initializer {
        marketFeeInPercent = marketFeeInPercent_;
        serviceFeeInToken = serviceFeeInToken_;
        wastedExpand = wastedExpand_;
        PERCENT = 100;
    }

    function listing(
        uint256 expandId,
        uint256 price,
        uint256 amount
    ) external override nonReentrant {
        require(price > 0, "WEM: invalid price");

        wastedExpand.safeTransferFrom(
            msg.sender,
            address(this),
            expandId,
            amount,
            ""
        );

        expandsOnSale[msg.sender][expandId].price = price;
        expandsOnSale[msg.sender][expandId].amount = expandsOnSale[msg.sender][
            expandId
        ].amount.add(amount);
        balancesOf[msg.sender].add(expandId);

        emit Listing(expandId, price, amount, msg.sender);
    }

    function delist(uint256 expandId) external override nonReentrant {
        uint256 amount = expandsOnSale[msg.sender][expandId].amount;

        expandsOnSale[msg.sender][expandId].price = 0;
        expandsOnSale[msg.sender][expandId].amount = 0;

        wastedExpand.transferFrom(
            address(this),
            msg.sender,
            expandId,
            amount,
            ""
        );
        balancesOf[msg.sender].remove(expandId);

        emit Delist(expandId, msg.sender);
    }

    function buy(
        uint256 expandId,
        address seller,
        uint256 amount,
        uint256 expectedPrice
    ) external payable override nonReentrant {
        uint256 price = expandsOnSale[seller][expandId].price * amount;
        address buyer = msg.sender;

        require(buyer != seller);
        require(price > 0, "Tunniverse: not on sale");
        require(price == expectedPrice);
        require(msg.value == price, "WEM: not enough");

        _makeTransaction(expandId, buyer, seller, price, amount);

        emit ExpandBought(expandId, buyer, seller, amount, price);
    }

    function offer(
        uint256 expandId,
        uint256 offerPrice,
        address seller,
        uint256 amount
    ) external payable override nonReentrant {
        address buyer = msg.sender;
        uint256 currentOffer = expandsOffer[seller][expandId][buyer].price;
        bool needRefund = offerPrice < currentOffer;
        uint256 requiredValue = needRefund ? 0 : offerPrice - currentOffer;

        require(buyer != seller, "WEM: cannot offer");
        require(offerPrice != currentOffer, "WEM: same offer");
        require(msg.value == requiredValue, "WEM: value invalid");

        expandsOffer[seller][expandId][buyer].price = offerPrice;
        expandsOffer[seller][expandId][buyer].amount = amount;

        if (needRefund) {
            uint256 returnedValue = currentOffer - offerPrice;

            (bool success, ) = buyer.call{value: returnedValue}("");
            require(success);
        }

        emit ExpandOffered(expandId, buyer, seller, amount, offerPrice);
    }

    function acceptOffer(
        uint256 expandId,
        address buyer,
        uint256 expectedPrice
    ) external override nonReentrant {
        address seller = msg.sender;
        uint256 offeredPrice = expandsOffer[seller][expandId][buyer].price;

        uint256 amount = expandsOffer[seller][expandId][buyer].amount;

        require(expectedPrice == offeredPrice);
        require(buyer != seller);

        expandsOffer[seller][expandId][buyer].price = 0;
        expandsOffer[seller][expandId][buyer].amount = 0;

        _makeTransaction(expandId, buyer, seller, offeredPrice, amount);

        emit ExpandBought(expandId, buyer, seller, amount, offeredPrice);
    }

    function abortOffer(uint256 expandId, address seller)
        external
        override
        nonReentrant
    {
        address caller = msg.sender;
        uint256 offerPrice = expandsOffer[seller][expandId][caller].price;

        require(offerPrice > 0);

        expandsOffer[seller][expandId][caller].price = 0;
        expandsOffer[seller][expandId][caller].amount = 0;

        (bool success, ) = caller.call{value: offerPrice}("");
        require(success);

        emit ExpandOfferCanceled(expandId, seller, caller);
    }

    function _makeTransaction(
        uint256 expandId,
        address buyer,
        address seller,
        uint256 price,
        uint256 amount
    ) private {
        uint256 marketFee = (price * marketFeeInPercent) / PERCENT;
        BuyInfo storage songInfo = expandsOnSale[seller][expandId];
        if (amount < songInfo.amount) {
            expandsOnSale[seller][expandId].amount = expandsOnSale[seller][
                expandId
            ].price.sub(amount);
        } else {
            expandsOnSale[seller][expandId].price = 0;
            expandsOnSale[seller][expandId].amount = 0;
        }

        (bool isTransferToSeller, ) = seller.call{value: price - marketFee}("");
        require(isTransferToSeller);

        (bool isTransferToTreasury, ) = owner().call{value: marketFee}("");
        require(isTransferToTreasury);

        wastedExpand.transferFrom(address(this), buyer, expandId, amount, "");
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155ReceiverUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
