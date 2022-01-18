//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract AcceptedTokenUpgradeable is Initializable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // Token to be used in the ecosystem.
    IERC20Upgradeable public acceptedToken;

    function initialize(IERC20Upgradeable tokenAddress) public initializer {
        acceptedToken = tokenAddress;
    }

    modifier collectTokenAsFee(uint256 amount, address destAddress) {
        require(
            acceptedToken.balanceOf(msg.sender) >= amount,
            "AcceptedToken: insufficient token balance"
        );
        _;
        acceptedToken.safeTransferFrom(msg.sender, destAddress, amount);
    }

    function collectTokenAsPrice(uint256 amount, address destAddress) public {
        require(
            acceptedToken.balanceOf(msg.sender) >= amount,
            "AcceptedToken: insufficient token balance"
        );
        acceptedToken.safeTransferFrom(msg.sender, destAddress, amount);
    }

    /**
     * @dev Sets accepted token using in the ecosystem.
     */
    function setAcceptedTokenContract(IERC20Upgradeable tokenAddr)
        external
        onlyOwner
    {
        require(address(tokenAddr) != address(0));
        acceptedToken = tokenAddr;
    }
}
