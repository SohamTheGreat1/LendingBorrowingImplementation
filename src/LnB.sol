// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

// to do-
// collateral = ETH
// lend = USDC
// collateral factor 
// liquidation threshold
// interest linear


import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {AggregatorV3Interface} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract sAAVE is Ownable{
    IERC20 public usdc;
    AggregatorV3Interface public priceFeed;
    uint256 public constant LIQUIDATION_THRESHOLD = 75; 
    uint256 public constant COLLATERAL_RATIO = 150;
    uint256 public interestRatePerSecond = 1e12;

    constructor(IERC20 _usdc, AggregatorV3Interface _priceFeed) Ownable(msg.sender){
        usdc = _usdc;
        priceFeed = _priceFeed;
    }

    event borrowed(address indexed user, uint256 amount);
    event deposited(address indexed user, uint256 amount);
    event withdrawn(address indexed user, uint256 amount);

    struct User {
        uint256 collateralisedETH;
        uint256 lendedUSDC;
        uint256 lastTransactionTime;
    }

    mapping(address => User) private users;

    function ETHPrice() public view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return uint256(price); 
    }

    function getUSDCBalance() public view returns (uint){
        return usdc.balanceOf(address(this));
    }

    function depositCollateral() public payable {
        require(msg.value > 0);
        User storage user = users[msg.sender];
        if (user.collateralisedETH > 0) {
            uint256 interest = calculateInterest(msg.sender);
            user.collateralisedETH += interest;
        }
        user.collateralisedETH += msg.value;
        user.lastTransactionTime = block.timestamp;
        emit deposited(msg.sender, msg.value);
    }

    function calculateInterest(address user) public view returns (uint256) {
        User storage u = users[user];
        if (u.collateralisedETH == 0 || u.lastTransactionTime == 0) return 0;
        uint256 timeElapsed = block.timestamp - u.lastTransactionTime;
        uint256 interest = (u.collateralisedETH * interestRatePerSecond * timeElapsed) / 1e18; 
        return interest;
    }

    function withdrawCollateral(uint256 amount) public {
        User storage user = users[msg.sender];
        uint256 interest = calculateInterest(msg.sender);
        uint256 totalCollateral = user.collateralisedETH + interest;
        require(totalCollateral >= amount);
        user.collateralisedETH = totalCollateral - amount;
        user.lastTransactionTime = block.timestamp;
        payable(msg.sender).transfer(amount);
        emit withdrawn(msg.sender, amount);
    }

    function borrow(uint256 amount) public {
        require(amount > 0);
        require(users[msg.sender].collateralisedETH > 0);
        require(users[msg.sender].lendedUSDC == 0);
        require(getUSDCBalance() >= amount);
        require(getCollateralRatio(msg.sender) < COLLATERAL_RATIO);
        users[msg.sender].lendedUSDC = amount;
        usdc.transfer(msg.sender, amount);
        emit borrowed(msg.sender, amount);
    }

    function getCollateralRatio(address user) public view returns (uint256) {
        require(users[user].lendedUSDC > 0);
        require(users[user].collateralisedETH > 0);
        return (users[user].collateralisedETH * ETHPrice() * 100) / users[user].lendedUSDC;
    }
    
    function repayLoan(uint256 amount) public {
        User storage user = users[msg.sender];
        require(user.lendedUSDC > 0);
        require(amount > 0);
        require(amount == user.lendedUSDC);
        usdc.transferFrom(msg.sender, address(this), amount);
        user.lendedUSDC -= amount;
        user.lastTransactionTime = block.timestamp;
    }
}