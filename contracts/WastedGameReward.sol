//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./utils/TokenWithdrawable.sol";

contract WastedGameReward is
EIP712,
AccessControl,
ReentrancyGuard,
TokenWithdrawable
{
    using SafeMath for uint256;

    event WithdrawSuccess(address user, uint256 amount, uint256 withdrawId);

    struct Withdraw {
        address user;
        uint256 amount;
        uint256 withdrawId;
    }

    IERC20 public acceptedToken;
    mapping(address => Withdraw) public _users;
    mapping(uint256 => bool) public isClaimed;
    bytes32 public constant SERVER_ROLE = keccak256("SERVER_ROLE");
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
    string private constant SIGNING_DOMAIN = "LazyWithdraw-WastedLands";
    string private constant SIGNATURE_VERSION = "1";

    constructor(IERC20 _acceptedToken)
    EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION)
    {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        acceptedToken = _acceptedToken;
    }

    function claim(Withdraw calldata withdraw, bytes memory signature)
    external
    nonReentrant
    {
        uint256 totalAmount = withdraw.amount;
        address signer = _verify(withdraw, signature);

        require(msg.sender == withdraw.user, "WAV: invalid sender");
        require(!isClaimed[withdraw.withdrawId], "WAV: already claimed");
        require(
            hasRole(SERVER_ROLE, signer),
            "WAV: Signature invalid or unauthorized"
        );
        require(
            acceptedToken.balanceOf(address(this)) > totalAmount,
            "WAV: sufficient balance"
        );
        isClaimed[withdraw.withdrawId] = true;
        acceptedToken.transfer(msg.sender, totalAmount);
        _users[msg.sender] = withdraw;

        emit WithdrawSuccess(msg.sender, totalAmount, withdraw.withdrawId);
    }

    function _hash(Withdraw calldata withdraw) internal view returns (bytes32) {
        return
        _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256(
                        "Withdraw(address user,uint256 amount,uint256 withdrawId)"
                    ),
                    withdraw.user,
                    withdraw.amount,
                    withdraw.withdrawId
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

    function _verify(Withdraw calldata withdraw, bytes memory signature)
    internal
    view
    returns (address)
    {
        bytes32 digest = _hash(withdraw);
        return ECDSA.recover(digest, signature);
    }
}
