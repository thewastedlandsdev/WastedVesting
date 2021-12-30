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
    event SaleAdded(uint saleId, string saleName, uint totalInSale, uint lockMonths, uint timeStartTGE, uint percentOnTGE, uint timeStartMonthly);

    struct Investor {
        uint tokenPerMonth;
        uint tokenOnTGE;
        uint totalTokenReceived;
        uint claimDateMonthly;
        uint claimDateTGE;
        uint claimed;
        uint claimedTimes;
    }

    struct Sale {
        string name;
        uint totalInSale;
        uint lockMonths;
        uint timeStartTGE; // time start claim tge
        uint percentOnTGE;
        uint timeStartMonthly; // time start claim month
        uint totalClaimed;
    }

    modifier onlyInvestor (address _address, uint saleId) {
        require(_investors[_address][saleId].tokenPerMonth > 0);
        _;
    }
    modifier onlyNotInBlacklist(address _address) {
        require(!blacklist[_address], "WI: blacklisted");
        _;
    }

    uint constant PERCENT = 100;
    uint constant MONTH = 2 minutes;
    IERC20 public acceptedToken;

    Sale[] public _saleInfo;

    mapping(address => mapping(uint => Investor)) public _investors;
    mapping(address => bool) public blacklist;

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

    function addInvestor(uint saleId, uint totalTokenReceived, address investor) external onlyOwner {
        require(_saleInfo[saleId].totalInSale > 0, "WI: invalid sale name");
        require(totalTokenReceived > 0, "WI: invalid number");
        require(investor != address(0), "WI: invalid address");
        require(_investors[investor][saleId].tokenPerMonth == 0, "WI: address used");

        uint _totalToken = totalTokenReceived;

        uint tokenOnTGE = _totalToken.mul(_saleInfo[saleId].percentOnTGE).div(PERCENT);
        uint tokenPerMonth = _totalToken.sub(tokenOnTGE).div(_saleInfo[saleId].lockMonths);
        uint claimDateMonthly = _saleInfo[saleId].timeStartMonthly;
        uint claimDateTGE = _saleInfo[saleId].timeStartTGE;

        require(_saleInfo[saleId].totalClaimed.add(_totalToken) <= _saleInfo[saleId].totalInSale, "WI: sufficient");

        _investors[investor][saleId] = Investor(tokenPerMonth, tokenOnTGE, _totalToken, claimDateMonthly, claimDateTGE, 0, 0);
        _saleInfo[saleId].totalClaimed = _saleInfo[saleId].totalClaimed.add(_totalToken);
    }

    function addSaleInfo(string memory saleName, uint totalInSale, uint lockMonths, uint timeStartTGE, uint percentOnTGE, uint timeStartMonthly) external onlyOwner {
        require(totalInSale > 0 && lockMonths > 0, "WI: invalid info");
        require(percentOnTGE < PERCENT);
        acceptedToken.safeTransferFrom(msg.sender, address(this), totalInSale);
        _saleInfo.push(Sale(saleName, totalInSale, lockMonths, timeStartTGE, percentOnTGE, timeStartMonthly, 0));
        uint _saleId = _saleInfo.length - 1;

        emit SaleAdded(_saleId, saleName, totalInSale, lockMonths, timeStartTGE, percentOnTGE, timeStartMonthly);
    }

    function claim(uint saleId) external onlyInvestor(msg.sender, saleId) onlyNotInBlacklist(msg.sender) nonReentrant {

        Sale memory saleInfo = _saleInfo[saleId];
        Investor storage investor = _investors[msg.sender][saleId];

        require(investor.claimedTimes <= saleInfo.lockMonths);

        if(investor.claimDateTGE != 0) {
            require(investor.claimDateTGE <= block.timestamp, "WI: not eligible");
            uint claimable = investor.tokenOnTGE;
            acceptedToken.safeTransfer(msg.sender, claimable);
            investor.claimDateTGE = 0;
            investor.claimed = investor.claimed.add(claimable);
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

    function withdrawInvestor(address _investor, uint saleId) external onlyOwner nonReentrant {
        require(blacklist[_investor]);
        Investor storage investor = _investors[_investor][saleId];
        uint remaining = investor.totalTokenReceived.sub(investor.claimed);
        
        acceptedToken.safeTransfer(msg.sender, remaining);

        investor.tokenPerMonth = 0;
        investor.tokenOnTGE = 0;
        investor.totalTokenReceived = 0;
        investor.claimDateMonthly = 0;
        investor.claimDateTGE = 0;
        investor.claimed = 0;
        investor.claimedTimes = 0;
        emit Claimed(msg.sender, remaining);
    }


    function withdrawEmergency(IERC20 token, uint256 amount, address to) external onlyOwner {
        token.safeTransfer(to, amount);
        emit TokenWithdrawn(address(token), amount, to);
    }

}