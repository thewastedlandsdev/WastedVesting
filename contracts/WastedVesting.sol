//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract WastedVesting is Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint;

    event TokenWithdrawn(address token, uint256 amount, address to);
    event Claimed(address _investor, uint amount);

    struct Investor {
        string saleName;
        uint tokenPerMonth;
        uint tokenOnTGE;
        uint percentInTotal;
        uint claimedDate;
        uint claimed;
    }

    struct Sale {
        uint totalInSale;
        uint lockMonths;
        uint timeStart;
        uint percentOnTGE;
        uint cliff;
        uint totalClaimed;
    }

    modifier onlyInvestor (address _address) {
        require(_investors[_address].tokenPerMonth > 0);
        _;
    }

    uint constant PERCENT = 100;
    IERC20 public acceptedToken;

    mapping(address => Investor) public _investors;
    mapping(string => Sale) public _saleInfo;

    constructor (IERC20 _acceptedToken) {
        acceptedToken = _acceptedToken;
    }

    function addInvestor(string memory saleName, uint percentInTotal, address investor) external onlyOwner {
        require(_saleInfo[saleName].totalInSale > 0, "WI: invalid sale name");
        require(percentInTotal > 0, "WI: invalid number");
        require(investor != address(0), "WI: invalid address");
        require(_investors[investor].tokenPerMonth == 0, "WI: address used");

        uint _totalToken = _saleInfo[saleName].totalInSale.mul(percentInTotal).div(PERCENT);
        uint _totalTokenOnTGE = _saleInfo[saleName].totalInSale.mul(_saleInfo[saleName].percentOnTGE).div(PERCENT);

        uint tokenOnTGE = _totalTokenOnTGE.mul(percentInTotal).div(PERCENT);
        uint tokenPerMonth = _totalToken.sub(tokenOnTGE).div(_saleInfo[saleName].lockMonths); 

        require(_saleInfo[saleName].totalClaimed.add(_totalToken) <= _saleInfo[saleName].totalInSale, "WI: sufficient");

        _investors[investor] = Investor(saleName, tokenPerMonth, tokenOnTGE, percentInTotal, 0, 0);
        _saleInfo[saleName].totalClaimed = _saleInfo[saleName].totalClaimed.add(_totalToken);
    }

    function addSaleInfo(string memory saleName, uint totalInSale, uint lockMonths, uint timeStart, uint percentOnTGE, uint cliff) external onlyOwner {
        require(totalInSale > 0 && lockMonths > 0 && timeStart > 0, "WI: invalid info");
        require(_saleInfo[saleName].totalInSale == 0, "WI: already added");
        acceptedToken.safeTransferFrom(msg.sender, address(this), totalInSale);
        _saleInfo[saleName] = Sale(totalInSale, lockMonths, timeStart, percentOnTGE, cliff, 0);
    }

    function claim() external onlyInvestor(msg.sender) {
        string memory saleName = _investors[msg.sender].saleName;
        Sale memory saleInfo = _saleInfo[saleName];
        Investor storage investor = _investors[msg.sender];
        

        if(investor.claimedDate == 0) {
            uint claimable = investor.tokenOnTGE;
            acceptedToken.safeTransfer(msg.sender, claimable);
            investor.claimedDate = saleInfo.timeStart.add(saleInfo.cliff);
            investor.claimed = investor.claimed.add(claimable);
        } else {
            uint claimable = investor.tokenPerMonth;
            require(investor.claimedDate <= block.timestamp, "WI: invalid time");
            require(investor.claimed + claimable <= saleInfo.totalInSale.mul(investor.percentInTotal).div(PERCENT));
            acceptedToken.safeTransfer(msg.sender, claimable);
            investor.claimedDate = investor.claimedDate.add(30 days);
            investor.claimed = investor.claimed.add(claimable);
        }
    }


    function withdrawToken(IERC20 token, uint256 amount, address to) external onlyOwner {
        token.safeTransfer(to, amount);
        emit TokenWithdrawn(address(token), amount, to);
    }

}