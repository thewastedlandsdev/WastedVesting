pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./interfaces/IWastedWarrior.sol";

contract WastedRenting is IERC721Receiver {
    IWastedWarrior public warriorContract;

    struct RentInfo {
        uint256 percent;
        address renter;
    }

    uint256 public fee;
    uint256 constant PERCENT = 100;
    mapping(uint256 => RentInfo) public _warriorsListing;
    mapping(uint256 => address) public _warriorsOwner;

    event WarriorListed(uint256 warriorId, uint256 percent);
    event WarriorDelisted(uint256 warriorId);
    event WarriorRented(uint256 warriorId);
    event EvictRenter(uint256 warriorId);

    function listing(uint256 warriorId, uint256 percent) external {
        bool _isBlacklisted = warriorContract.getWarriorInBlacklist(warriorId);
        require(_isBlacklisted, "WR: blacklisted");
        require(percent > 0 && percent < 100, "WR: invalid percent");
        warriorContract.safeTransferFrom(msg.sender, address(this), warriorId);
        _warriorsListing[warriorId].percent = percent;
        _warriorsOwner[warriorId] = msg.sender;

        emit WarriorListed(warriorId, percent);
    }

    function setPercent(uint256 warriorId, uint256 percent) external {
        require(
            _warriorsOwner[warriorId] == msg.sender &&
                _warriorsOwner[warriorId] != address(0),
            "WR: invalid sender"
        );
        require(percent > 0 && percent < 100, "WR: invalid percent");
        _warriorsListing[warriorId].percent = percent;
    }

    function rent(uint256 warriorId) external {
        require(_warriorsOwner[warriorId] != address(0), "WR: Not listed");
        RentInfo storage rentInfo = _warriorsListing[warriorId];
        rentInfo.renter = msg.sender;

        emit WarriorRented(warriorId);
    }

    function evictRenter(uint256 warriorId) external {
        require(
            _warriorsOwner[warriorId] == msg.sender,
            "WR: not owner of warrior"
        );
        RentInfo storage rentInfo = _warriorsListing[warriorId];
        rentInfo.renter = address(0);

        emit EvictRenter(warriorId);
    }

    function delist(uint256 warriorId) external {
        address owner = _warriorsOwner[warriorId];
        require(owner == msg.sender, "WR: invalid sender");
        warriorContract.transferFrom(address(this), owner, warriorId);
        _warriorsListing[warriorId].percent = 0;
        _warriorsListing[warriorId].renter = address(0);
        _warriorsOwner[warriorId] = address(0);

        emit WarriorDelisted(warriorId);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external override returns (bytes4) {
        return
            bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }
}
