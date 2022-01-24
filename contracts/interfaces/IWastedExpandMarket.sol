//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IWastedExpandMarket {
    event Listing(
        uint256 expandId,
        uint256 price,
        uint256 amount,
        address seller
    );
    event Delist(uint256 expandId, address seller);

    event ExpandBought(
        uint256 expandId,
        address buyer,
        address seller,
        uint256 amount,
        uint256 price
    );

    event ExpandOffered(
        uint256 expandId,
        address buyer,
        address seller,
        uint256 amount,
        uint256 price
    );

    event ExpandOfferCanceled(uint256 expandId, address seller, address caller);

    struct BuyInfo {
        uint256 amount;
        uint256 price;
    }

    function listing(
        uint256 expandId,
        uint256 price,
        uint256 amount
    ) external;

    function delist(uint256 expandId) external;

    function buy(
        uint256 expandId,
        address seller,
        uint256 expectedPrice
    ) external payable;

    function offer(
        uint256 expandId,
        uint256 offerPrice,
        address seller
    ) external payable;

    function acceptOffer(
        uint256 expandId,
        address buyer,
        uint256 expectedPrice
    ) external;

    function abortOffer(uint256 expandId, address seller) external;
}
