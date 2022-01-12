//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "./PermissionGroup.sol";

contract AcceptedToken is PermissionGroup {
    using SafeERC20 for IERC20;

    // Token to be used in the ecosystem.
    IERC20 public acceptedToken;

    constructor(IERC20 tokenAddress) {
        acceptedToken = tokenAddress;
    }

    modifier collectTokenAsFee(uint256 amount, address destAddr) {
        require(
            acceptedToken.balanceOf(msg.sender) >= amount,
            "AcceptedToken: insufficient token balance"
        );
        _;
        acceptedToken.safeTransferFrom(msg.sender, destAddr, amount);
    }

    /**
     * @dev Sets accepted token using in the ecosystem.
     */
    function setAcceptedTokenContract(IERC20 tokenAddr) external onlyOwner {
        require(address(tokenAddr) != address(0));
        acceptedToken = tokenAddr;
    }
}
