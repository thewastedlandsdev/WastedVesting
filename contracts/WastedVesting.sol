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

contract WastedVesting is
    EIP712,
    AccessControl,
    ReentrancyGuard,
    TokenWithdrawable
{
    using SafeMath for uint256;

    event Claimed(address investorAddress, uint256 totalClaim, uint256 claimId);

    struct Investor {
        address investorAddress;
        uint256 totalClaim;
        uint256 claimId;
    }

    IERC20 public acceptedToken;
    mapping(address => Investor) public _investors;
    mapping(uint256 => bool) public isClaimed;
    bytes32 public constant SERVER_ROLE = keccak256("SERVER_ROLE");
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
    string private constant SIGNING_DOMAIN = "LazyClaiming-WastedLands";
    string private constant SIGNATURE_VERSION = "1";

    constructor(IERC20 _acceptedToken)
        EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION)
    {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        acceptedToken = _acceptedToken;
    }

    function claim(Investor calldata investor, bytes memory signature)
        external
        nonReentrant
    {
        uint256 totalClaim = investor.totalClaim;
        address signer = _verify(investor, signature);

        require(msg.sender == investor.investorAddress, "WAV: invalid sender");
        require(!isClaimed[investor.claimId], "WAV: already claimed");
        require(
            hasRole(SERVER_ROLE, signer),
            "WAV: Signature invalid or unauthorized"
        );
        require(
            acceptedToken.balanceOf(address(this)) > totalClaim,
            "WAV: sufficient balance"
        );
        isClaimed[investor.claimId] = true;
        acceptedToken.transfer(msg.sender, totalClaim);
        _investors[msg.sender] = investor;

        emit Claimed(msg.sender, totalClaim, investor.claimId);
    }

    function _hash(Investor calldata investor) internal view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        keccak256(
                            "Investor(address investorAddress,uint256 totalClaim,uint256 claimId)"
                        ),
                        investor.investorAddress,
                        investor.totalClaim,
                        investor.claimId
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

    function _verify(Investor calldata investor, bytes memory signature)
        internal
        view
        returns (address)
    {
        bytes32 digest = _hash(investor);
        return ECDSA.recover(digest, signature);
    }
}
