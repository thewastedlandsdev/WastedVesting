pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "./interfaces/IWastedExpandCollab.sol";
import "./utils/AcceptedTokenUpgradeable.sol";
import "./interfaces/IWastedExpandMarket.sol";
import "./utils/AcceptedTokenUpgradeable.sol";

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
        uint256 serviceFeeInToken_,
        IERC20Upgradeable tokenAddress
    ) public initializer {
        AcceptedTokenUpgradeable.initialize(tokenAddress);
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
        uint256 totalAmount = expandsOnSale[msg.sender][expandId].amount.add(
            amount
        );
        wastedExpand.safeTransferFrom(
            msg.sender,
            address(this),
            expandId,
            amount,
            ""
        );

        expandsOnSale[msg.sender][expandId].price = price;
        expandsOnSale[msg.sender][expandId].amount = totalAmount;
        balancesOf[msg.sender].add(expandId);

        emit Listing(expandId, price, totalAmount, msg.sender);
    }

    function delist(uint256 expandId) external override nonReentrant {
        uint256 amount = expandsOnSale[msg.sender][expandId].amount;
        require(amount > 0, "WEM: invalid");
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
        uint256 expectedPrice
    ) external payable override nonReentrant {
        uint256 price = expandsOnSale[seller][expandId].price;
        uint256 amount = expandsOnSale[seller][expandId].amount;
        address buyer = msg.sender;
        uint256 currentOffer = expandsOffer[seller][expandId][buyer].price;

        require(buyer != seller);
        require(price > 0, "WEM: not on sale");
        require(price == expectedPrice);
        require(msg.value == price, "WEM: not enough");

        if (currentOffer > 0) {
            expandsOffer[seller][expandId][buyer].price = 0;
            expandsOffer[seller][expandId][buyer].amount = 0;
            collectTokenAsPrice(currentOffer, buyer);
        }

        _makeTransaction(expandId, buyer, seller, price, amount);

        emit ExpandBought(expandId, buyer, seller, amount, price);
    }

    function offer(
        uint256 expandId,
        uint256 offerPrice,
        address seller
    ) external payable override nonReentrant {
        address buyer = msg.sender;
        uint256 currentOffer = expandsOffer[seller][expandId][buyer].price;
        bool needRefund = offerPrice < currentOffer;
        uint256 requiredValue = needRefund ? 0 : offerPrice - currentOffer;
        uint256 amount = expandsOnSale[seller][expandId].amount;

        require(buyer != seller, "WEM: cannot offer");
        require(offerPrice != currentOffer, "WEM: same offer");
        require(msg.value == requiredValue, "WEM: value invalid");

        expandsOffer[seller][expandId][buyer].price = offerPrice;
        expandsOffer[seller][expandId][buyer].amount = amount;

        if (needRefund) {
            uint256 returnedValue = currentOffer - offerPrice;

            collectTokenAsPrice(returnedValue, buyer);
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

        uint256 amount = expandsOnSale[seller][expandId].amount;

        require(
            amount == expandsOffer[seller][expandId][buyer].amount,
            "WEM: invalid offer"
        );
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

        collectTokenAsPrice(offerPrice, caller);

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

        expandsOnSale[seller][expandId].price = 0;
        expandsOnSale[seller][expandId].amount = 0;

        collectTokenAsPrice(price - marketFee, seller);
        collectTokenAsPrice(marketFee, owner());

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
