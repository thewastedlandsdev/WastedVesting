//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IWastedWarrior.sol";
import "./interfaces/IWastedStaking.sol";
import "./utils/PermissionGroup.sol";

contract WastedStaking is
    PermissionGroup,
    IWastedStaking,
    IERC721Receiver,
    EIP712,
    AccessControl,
    ReentrancyGuard
{
    using SafeMath for uint256;

    address private serverAddress;
    bytes32 public constant SERVER_ROLE = keccak256("SERVER_ROLE");
    string private constant SIGNING_DOMAIN = "LazyStaking-WastedWarrior";
    string private constant SIGNATURE_VERSION = "1";
    mapping(uint256 => address) public _ownerWarriorById;
    mapping(uint256 => bool) public warriorsStaked;

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
    mapping(uint256 => uint256) public _totalWarriorStaked;

    constructor(IWastedWarrior warriorAddress, uint256 feeClaim_)
        EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION)
    {
        warriorContract = warriorAddress;
        feeClaim = feeClaim_;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function setServerAddress(address _serverAddress) external onlyOwner {
        require(_serverAddress != address(0));
        serverAddress = _serverAddress;
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

    function getWarriorsStaked(address account, uint256 poolId)
        external
        view
        returns (uint256[] memory)
    {
        return _stakers[account][poolId].warriorIds;
    }

    function addPool(
        string memory name,
        uint256 lockedTimes,
        uint256 totalRewards,
        uint256 requiredWarriors,
        uint256 endTime,
        RarityPool rarityPool
    ) external onlyOwner {
        require(lockedTimes > 0 && totalRewards > 0, "WS: invalid info");
        _pools.push(
            WastedPool(
                name,
                lockedTimes,
                totalRewards,
                0,
                requiredWarriors,
                endTime,
                rarityPool
            )
        );
        uint256 poolId = _pools.length.sub(1);
        emit Pool(
            poolId,
            name,
            lockedTimes,
            totalRewards,
            requiredWarriors,
            endTime,
            rarityPool
        );
    }

    function updatePool(
        uint256 poolId,
        string memory name,
        uint256 lockedTimes,
        uint256 totalRewards,
        uint256 requiredWarriors,
        uint256 endTime,
        RarityPool rarityPool
    ) external onlyOwner {
        WastedPool storage pool = _pools[poolId];
        require(
            lockedTimes > 0 && totalRewards >= pool.staked,
            "WS: invalid info"
        );

        pool.name = name;
        pool.lockedTimes = lockedTimes;
        pool.totalRewards = totalRewards;
        pool.requiredWarriors = requiredWarriors;
        pool.endTime = endTime;
        pool.rarityPool = rarityPool;

        emit Pool(
            poolId,
            name,
            lockedTimes,
            totalRewards,
            requiredWarriors,
            endTime,
            rarityPool
        );
    }

    function stake(
        uint256 poolId,
        Warrior calldata warrior,
        bytes memory signature
    ) external override nonReentrant {
        Staker storage staker = _stakers[msg.sender][poolId];
        WastedPool storage pool = _pools[poolId];
        uint256[] memory warriorIds = warrior.warriorIds;
        address signer = _verify(warrior, signature);

        require(
            hasRole(SERVER_ROLE, signer),
            "WS: Signature invalid or unauthorized"
        );

        require(
            block.timestamp.add(pool.lockedTimes) <= pool.endTime,
            "WS: pool ended"
        );

        require(
            warriorIds.length.mod(pool.requiredWarriors) == 0 &&
                warriorIds.length == warrior.rarity.length,
            "WS: invalid length"
        );
        require(
            staker.timeStartLock == 0 && staker.timeClaim == 0,
            "WS: address used"
        );
        require(pool.staked < pool.totalRewards, "WS: full");

        staker.timeStartLock = block.timestamp;
        staker.timeClaim = block.timestamp.add(pool.lockedTimes);

        for (uint256 i = 0; i < warriorIds.length; i++) {
            require(!warriorsStaked[warriorIds[i]], "WS: warriors staked");

            if (uint256(pool.rarityPool) == 1) {
                require(warrior.rarity[i] == 4, "WS: invalid warrior");
            } else {
                require(warrior.rarity[i] < 4, "WS: invalid warrior");
            }
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
            _ownerWarriorById[warriorIds[i]] = msg.sender;
            _totalWarriorStaked[poolId] = _totalWarriorStaked[poolId].add(1);
        }

        pool.staked = pool.staked.add(
            warriorIds.length.div(pool.requiredWarriors)
        );

        emit Staked(warriorIds, poolId, msg.sender);
    }

    function unstake(uint256 poolId) external override nonReentrant {
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

            _ownerWarriorById[warriorIds[i]] = address(0);
            _totalWarriorStaked[poolId] = _totalWarriorStaked[poolId].sub(1);
        }

        staker.warriorIds = helper;
        pool.staked = pool.staked.sub(
            warriorIds.length.div(pool.requiredWarriors)
        );

        emit Unstaked(warriorIds, poolId, msg.sender);
    }

    function claim(uint256 poolId) external payable override nonReentrant {
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

        for (uint256 i = 0; i < warriorIds.length; i++) {
            bool _isBlacklisted = warriorContract.getWarriorInBlacklist(
                warriorIds[i]
            );
            require(!_isBlacklisted, "WS: warrior blacklisted");
            warriorsStaked[warriorIds[i]] = true;
            warriorContract.transferFrom(
                address(this),
                msg.sender,
                warriorIds[i]
            );
            _ownerWarriorById[warriorIds[i]] = address(0);
        }
        staker.warriorIds = helper;

        (bool isTransferToOwner, ) = serverAddress.call{value: msg.value}("");
        require(isTransferToOwner);

        emit Claimed(msg.sender, poolId, warriorIds);
    }

    function _hash(Warrior calldata warrior) internal view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        keccak256(
                            "Warrior(uint256[] warriorIds,uint8[] rarity)"
                        ),
                        keccak256(abi.encodePacked(warrior.warriorIds)),
                        keccak256(abi.encodePacked(warrior.rarity))
                    )
                )
            );
    }

    function getChainID() external view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

    function _verify(Warrior calldata warrior, bytes memory signature)
        internal
        view
        returns (address)
    {
        bytes32 digest = _hash(warrior);
        return ECDSA.recover(digest, signature);
    }

    function withdrawEmergency(
        uint256[] memory warriorIds,
        uint256 poolId,
        address stakerAddress
    ) external onlyOwner {
        Staker storage staker = _stakers[stakerAddress][poolId];
        WastedPool memory pool = _pools[poolId];
        require(pool.endTime <= block.timestamp, "WS: not ended");

        staker.timeStartLock = 0;
        staker.timeClaim = 0;

        for (uint256 i = 0; i < warriorIds.length; i++) {
            bool _isBlacklisted = warriorContract.getWarriorInBlacklist(
                staker.warriorIds[i]
            );
            require(
                _ownerWarriorById[warriorIds[i]] == stakerAddress,
                "WS: staker is not owner of hero"
            );
            require(!_isBlacklisted, "WS: warrior blacklisted");
            warriorContract.transferFrom(
                address(this),
                stakerAddress,
                staker.warriorIds[i]
            );
            _ownerWarriorById[warriorIds[i]] = address(0);
        }
        staker.warriorIds = helper;
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
