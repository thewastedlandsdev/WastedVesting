//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract TokenHelper is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Token to be used in the ecosystem.
    IERC20 public acceptedToken;

    constructor(IERC20 tokenAddress) {
        acceptedToken = tokenAddress;
    }

    modifier collectToken(uint256 amount, address destAddr) {
        require(
            acceptedToken.balanceOf(msg.sender) >= amount,
            "AcceptedToken: insufficient token balance"
        );
        _;
        acceptedToken.safeTransferFrom(msg.sender, destAddr, amount);
    }

    function repayWithReward(
        uint256 amount,
        address destAddr,
        uint256 reward
    ) external {
        acceptedToken.transferFrom(address(this), destAddr, amount.add(reward));
    }

    /**
     * @dev Sets accepted token using in the ecosystem.
     */
    function setAcceptedTokenContract(IERC20 tokenAddr) external onlyOwner {
        require(address(tokenAddr) != address(0));
        acceptedToken = tokenAddr;
    }
}
