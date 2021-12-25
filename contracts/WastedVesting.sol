//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract WastedVesting is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint;

    event TokenWithdrawn(address token, uint256 amount, address to);
    event Claimed(address _investor, uint amount);
    event Blacklist(address _investor, bool lock);

    struct Investor {
        string saleName;
        uint tokenPerMonth;
        uint tokenOnTGE;
        uint totalTokenReceived;
        uint claimDateMonthly;
        uint claimDateTGE;
        uint claimed;
        uint claimedTimes;
    }

    struct Sale {
        uint totalInSale;
        uint lockMonths;
        uint timeStartTGE; // time start claim tge
        uint percentOnTGE;
        uint timeStartMonthly; // time start claim month
        uint totalClaimed;
    }

    modifier onlyInvestor (address _address) {
        require(_investors[_address].tokenPerMonth > 0);
        _;
    }
    modifier onlyNotInBlacklist(address _address) {
        require(!blacklist[_address], "WI: blacklisted");
        _;
    }

    uint constant PERCENT = 100;
    uint constant MONTH = 2 minutes;
    IERC20 public acceptedToken;

    mapping(address => Investor) public _investors;
    mapping(string => Sale) public _saleInfo;
    mapping(address => bool) blacklist;

    constructor (IERC20 _acceptedToken) {
        acceptedToken = _acceptedToken;
    }

    function addBlacklist(address _address) external onlyOwner {
        blacklist[_address] = true;
        emit Blacklist(_address, true);
    }

    function removeBlacklist(address _address) external onlyOwner {
        blacklist[_address] = false;
        emit Blacklist(_address, false);
    }

    function addInvestor(string memory saleName, uint totalTokenReceived, address investor) external onlyOwner {
        require(_saleInfo[saleName].totalInSale > 0, "WI: invalid sale name");
        require(totalTokenReceived > 0, "WI: invalid number");
        require(investor != address(0), "WI: invalid address");
        require(_investors[investor].tokenPerMonth == 0, "WI: address used");

        uint _totalToken = totalTokenReceived;

        uint tokenOnTGE = _totalToken.mul(_saleInfo[saleName].percentOnTGE).div(PERCENT);
        uint tokenPerMonth = _totalToken.sub(tokenOnTGE).div(_saleInfo[saleName].lockMonths);
        uint claimDateMonthly = _saleInfo[saleName].timeStartMonthly;
        uint claimDateTGE = _saleInfo[saleName].timeStartTGE;

        require(_saleInfo[saleName].totalClaimed.add(_totalToken) <= _saleInfo[saleName].totalInSale, "WI: sufficient");


        _investors[investor] = Investor(saleName, tokenPerMonth, tokenOnTGE, _totalToken, claimDateMonthly, claimDateTGE, 0, 0);
        _saleInfo[saleName].totalClaimed = _saleInfo[saleName].totalClaimed.add(_totalToken);
    }

    function addSaleInfo(string memory saleName, uint totalInSale, uint lockMonths, uint timeStartTGE, uint percentOnTGE, uint timeStartMonthly) external onlyOwner {
        require(totalInSale > 0 && lockMonths > 0, "WI: invalid info");
        require(_saleInfo[saleName].totalInSale == 0, "WI: already added");
        require(percentOnTGE < PERCENT);
        acceptedToken.safeTransferFrom(msg.sender, address(this), totalInSale);
        _saleInfo[saleName] = Sale(totalInSale, lockMonths, timeStartTGE, percentOnTGE, timeStartMonthly, 0);
    }

    function claim() external onlyInvestor(msg.sender) onlyNotInBlacklist(msg.sender) nonReentrant {
        string memory saleName = _investors[msg.sender].saleName;
        Sale memory saleInfo = _saleInfo[saleName];
        Investor storage investor = _investors[msg.sender];

        if(saleInfo.timeStartTGE == 0) {
            require(investor.claimedTimes <= saleInfo.lockMonths);
        } else {
            require(investor.claimedTimes <= saleInfo.lockMonths + 1);
        }

        if(investor.claimDateTGE != 0) {
            require(investor.claimDateTGE <= block.timestamp, "WI: not eligible");
            uint claimable = investor.tokenOnTGE;
            acceptedToken.safeTransfer(msg.sender, claimable);
            investor.claimDateTGE = 0;
            investor.claimed = investor.claimed.add(claimable);
            investor.claimedTimes = investor.claimedTimes.add(1);
            emit Claimed(msg.sender, claimable);
        } else {
            uint claimable = investor.tokenPerMonth;
            require(investor.claimDateMonthly <= block.timestamp, "WI: not eligible");
            require(investor.claimed + claimable <= investor.totalTokenReceived);
            acceptedToken.safeTransfer(msg.sender, claimable);
            investor.claimDateMonthly = investor.claimDateMonthly.add(MONTH);
            investor.claimed = investor.claimed.add(claimable);
            investor.claimedTimes = investor.claimedTimes.add(1);
            emit Claimed(msg.sender, claimable);
        }
    }

    function claimController(address _investor) external onlyOwner nonReentrant {
        require(blacklist[_investor]);
        string memory saleName = _investors[_investor].saleName;
        Sale memory saleInfo = _saleInfo[saleName];
        Investor storage investor = _investors[_investor];

        if(saleInfo.timeStartTGE == 0) {
            require(investor.claimedTimes <= saleInfo.lockMonths);
        } else {
            require(investor.claimedTimes <= saleInfo.lockMonths + 1);
        }

        if(investor.claimDateTGE != 0) {
            require(investor.claimDateTGE <= block.timestamp, "WI: not eligible");
            uint claimable = investor.tokenOnTGE;
            acceptedToken.safeTransfer(msg.sender, claimable);
            investor.claimDateTGE = 0;
            investor.claimed = investor.claimed.add(claimable);
            investor.claimedTimes = investor.claimedTimes.add(1);
            emit Claimed(msg.sender, claimable);
        } else {
            uint claimable = investor.tokenPerMonth;
            require(investor.claimDateMonthly <= block.timestamp, "WI: not eligible");
            require(investor.claimed + claimable <= investor.totalTokenReceived);
            acceptedToken.safeTransfer(msg.sender, claimable);
            investor.claimDateMonthly = investor.claimDateMonthly.add(MONTH);
            investor.claimed = investor.claimed.add(claimable);
            investor.claimedTimes = investor.claimedTimes.add(1);
            emit Claimed(msg.sender, claimable);
        }
    }


    function withdrawToken(IERC20 token, uint256 amount, address to) external onlyOwner {
        token.safeTransfer(to, amount);
        emit TokenWithdrawn(address(token), amount, to);
    }

}