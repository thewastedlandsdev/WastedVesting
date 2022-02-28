//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract WastedVesting is EIP712, AccessControl, ReentrancyGuard {
    using SafeMath for uint256;

    struct Investor {
        uint256 totalClaim;
        uint256 saleId;
    }

    IERC20 public acceptedToken;
    mapping(address => Investor) public _investors;
    address private serverAddress;
    bytes32 public constant SERVER_ROLE = keccak256("SERVER_ROLE");
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
    string private constant SIGNING_DOMAIN = "LazyClaiming-WastedLands";
    string private constant SIGNATURE_VERSION = "1";

    constructor(address _serverAddress, IERC20 _acceptedToken)
        EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION)
    {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        serverAddress = _serverAddress;
        acceptedToken = _acceptedToken;
    }

    function setServerAddress(address _serverAddress)
        external
        onlyRole(CONTROLLER_ROLE)
    {
        require(_serverAddress != address(0));
        serverAddress = _serverAddress;
    }

    function claim(Investor calldata investor, bytes memory signature)
        external
        nonReentrant
    {
        uint256 totalClaim = investor.totalClaim;
        address signer = _verify(investor, signature);

        require(
            hasRole(SERVER_ROLE, signer),
            "WS: Signature invalid or unauthorized"
        );
        require(
            acceptedToken.balanceOf(address(this)) > totalClaim,
            "WAV: sufficient balance"
        );

        acceptedToken.transfer(msg.sender, totalClaim);
        _investors[msg.sender] = investor;
    }

    function _hash(Investor calldata investor) internal view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        keccak256(
                            "Investor(uint256 totalClaim,uint256 saleId)"
                        ),
                        keccak256(abi.encodePacked(investor.totalClaim)),
                        keccak256(abi.encodePacked(investor.saleId))
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

    function withdraw(uint256 amount) external onlyRole(CONTROLLER_ROLE) {
        uint256 balance = acceptedToken.balanceOf(address(this));
        require(balance >= amount, "WAV: sufficient balance");
        acceptedToken.transfer(msg.sender, amount);
    }
}
