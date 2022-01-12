pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./utils/AcceptedToken.sol";
import "./interfaces/IWastedWarrior.sol";

contract WastedCrossbred is EIP712, AcceptedToken, AccessControl {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IWastedWarrior public warriorContract;

    bytes32 public constant SERVER_ROLE = keccak256("SERVER_ROLE");
    string private constant SIGNING_DOMAIN = "LazyCrossbred-WastedWarrior";
    string private constant SIGNATURE_VERSION = "1";

    struct WarriorInfo {
        uint256[] warriorIds;
        uint256[] lockedParts;
    }

    constructor(IERC20 _acceptedToken, IWastedWarrior _warriorContract)
        EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION)
        AcceptedToken(_acceptedToken)
    {
        warriorContract = _warriorContract;
    }

    function breeding(WarriorInfo calldata warrior, bytes memory signature)
        external
    {
        address signer = _verify(warrior, signature);

        require(
            hasRole(SERVER_ROLE, signer),
            "WS: Signature invalid or unauthorized"
        );
    }

    function _hash(WarriorInfo calldata warrior)
        internal
        view
        returns (bytes32)
    {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        keccak256(
                            "WarriorInfo(uint256[] warriorIds,uint[] lockedParts)"
                        ),
                        keccak256(abi.encodePacked(warrior.warriorIds)),
                        keccak256(abi.encodePacked(warrior.lockedParts))
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

    function _verify(WarriorInfo calldata warrior, bytes memory signature)
        internal
        view
        returns (address)
    {
        bytes32 digest = _hash(warrior);
        return ECDSA.recover(digest, signature);
    }
}
