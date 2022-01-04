//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./interfaces/IWastedWarrior.sol";
import "./interfaces/IWastedStaking.sol";
import "./utils/PermissionGroup.sol";

contract WastedStaking is
    PermissionGroup,
    IWastedStaking,
    IERC721Receiver,
    EIP712,
    AccessControl
{
    using SafeMath for uint256;

    bytes32 public constant SERVER_ROLE = keccak256("SERVER_ROLE");
    string private constant SIGNING_DOMAIN = "LazyStaking-WastedWarrior";
    string private constant SIGNATURE_VERSION = "1";

    struct Staker {
        uint256 timeStartLock;
        uint256 timeClaim;
        uint256[] warriorIds;
    }

    WastedPool[] public _pools;

    IWastedWarrior public warriorContract;
    mapping(address => mapping(uint256 => Staker)) public _stakers;
    uint256 public feeClaim;
    uint256[] private helper;

    constructor(IWastedWarrior warriorAddress, uint256 feeClaim_)
        EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION)
    {
        warriorContract = warriorAddress;
        feeClaim = feeClaim_;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function setWastedWarriorContract(IWastedWarrior warriorAddress)
        external
        onlyOwner
    {
        require(address(warriorAddress) != address(0));
        warriorContract = warriorAddress;
    }

    function setFeeClaim(uint256 feeClaim_) external onlyOwner {
        feeClaim = feeClaim_;
    }

    function getPool() external view returns (WastedPool[] memory) {
        return _pools;
    }

    function addPool(
        string memory name,
        uint256 lockedMonths,
        uint256 totalRewards,
        uint256 maxWarriorPerAddress,
        RarityPool rarityPool
    ) external onlyOwner {
        require(lockedMonths > 0 && totalRewards > 0, "WS: invalid info");
        _pools.push(
            WastedPool(
                name,
                lockedMonths,
                totalRewards,
                0,
                maxWarriorPerAddress,
                rarityPool
            )
        );
        uint256 poolId = _pools.length.sub(1);
        emit Pool(
            poolId,
            name,
            lockedMonths,
            totalRewards,
            maxWarriorPerAddress,
            rarityPool
        );
    }

    function udpatePool(
        uint256 poolId,
        string memory name,
        uint256 lockedMonths,
        uint256 totalRewards,
        uint256 maxWarriorPerAddress,
        RarityPool rarityPool
    ) external onlyOwner {
        WastedPool storage pool = _pools[poolId];
        require(
            lockedMonths > 0 && totalRewards >= pool.staked,
            "WS: invalid info"
        );

        pool.name = name;
        pool.lockedMonths = lockedMonths;
        pool.totalRewards = totalRewards;
        pool.maxWarriorPerAddress = maxWarriorPerAddress;
        pool.rarityPool = rarityPool;

        emit Pool(
            poolId,
            name,
            lockedMonths,
            totalRewards,
            maxWarriorPerAddress,
            rarityPool
        );
    }

    function stake(uint256 poolId, Warrior calldata warrior) external override {
        Staker storage staker = _stakers[msg.sender][poolId];
        WastedPool storage pool = _pools[poolId];
        uint256[] memory warriorIds = warrior.warriorIds;
        address signer = _verify(warrior);

        require(
            hasRole(SERVER_ROLE, signer),
            "WS: Signature invalid or unauthorized"
        );

        require(
            warriorIds.length <= pool.maxWarriorPerAddress,
            "WS: out of range"
        );
        require(
            staker.timeStartLock == 0 && staker.timeClaim == 0,
            "WS: address used"
        );
        require(pool.staked <= pool.totalRewards, "WS: full");

        staker.timeStartLock = block.timestamp;
        staker.timeClaim = block.timestamp.add(pool.lockedMonths);
        for (uint256 i = 0; i < warriorIds.length; i++) {
            uint256 _isListing = warriorContract.getWarriorListing(
                warriorIds[i]
            );
            bool _isBlacklisted = warriorContract.getWarriorInBlacklist(
                warriorIds[i]
            );
            require(_isListing == 0, "WS: delist first");
            require(!_isBlacklisted, "WS: warrior blacklisted");
            warriorContract.safeTransferFrom(
                msg.sender,
                address(this),
                warriorIds[i]
            );
            staker.warriorIds.push(warriorIds[i]);
            pool.staked = pool.staked.add(1);
        }

        emit Staked(warriorIds, poolId, msg.sender);
    }

    function unstake(uint256 poolId) external override {
        Staker storage staker = _stakers[msg.sender][poolId];
        WastedPool storage pool = _pools[poolId];
        uint256[] memory warriorIds = staker.warriorIds;

        require(
            staker.timeStartLock != 0 && staker.timeClaim != 0,
            "WS: address used"
        );
        require(staker.timeClaim > block.timestamp, "WS: Claim func");

        staker.timeStartLock = 0;
        staker.timeClaim = 0;

        for (uint256 i = 0; i < staker.warriorIds.length; i++) {
            bool _isBlacklisted = warriorContract.getWarriorInBlacklist(
                staker.warriorIds[i]
            );
            require(!_isBlacklisted, "WS: warrior blacklisted");
            warriorContract.transferFrom(
                address(this),
                msg.sender,
                staker.warriorIds[i]
            );
            pool.staked = pool.staked.sub(1);
        }
        staker.warriorIds = helper;

        emit Unstaked(warriorIds, poolId, msg.sender);
    }

    function claim(uint256 poolId) external payable override {
        require(msg.value == feeClaim, "WS: not enough");
        Staker storage staker = _stakers[msg.sender][poolId];
        uint256[] memory warriorIds = staker.warriorIds;

        require(
            staker.timeStartLock != 0 && staker.timeClaim != 0,
            "WS: address used"
        );
        require(staker.timeClaim < block.timestamp, "WS: Unstake func");

        staker.timeStartLock = 0;
        staker.timeClaim = 0;

        for (uint256 i = 0; i < staker.warriorIds.length; i++) {
            bool _isBlacklisted = warriorContract.getWarriorInBlacklist(
                staker.warriorIds[i]
            );
            require(!_isBlacklisted, "WS: warrior blacklisted");
            warriorContract.transferFrom(
                address(this),
                msg.sender,
                staker.warriorIds[i]
            );
        }
        staker.warriorIds = helper;

        (bool isTransferToOwner, ) = owner().call{value: msg.value}("");
        require(isTransferToOwner);

        emit Claimed(msg.sender, poolId, warriorIds);
    }

    function _hash(Warrior calldata warrior) internal view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        keccak256(
                            "Warrior(uint256[] warriorIds, RarityWarrior[] rarity)"
                        ),
                        warrior.warriorIds,
                        warrior.rarity
                    )
                )
            );
    }

    function _verify(Warrior calldata warrior) internal view returns (address) {
        bytes32 digest = _hash(warrior);
        return ECDSA.recover(digest, warrior.signature);
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
