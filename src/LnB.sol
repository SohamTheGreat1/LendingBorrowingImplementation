// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

// to do-
// collateral = ETH
// lend = USDC
// collateral factor 
// liquidation threshold
// interest linear


import {AggregatorV3Interface} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract sAAVE {
    IERC20 public usdc;
    AggregatorV3Interface public priceFeedETH;
    uint256 public constant LIQUIDATION_THRESHOLD = 75; 
    uint256 public constant COLLATERAL_RATIO = 150;
    uint256 public interestRatePerSecond = 1e12;
    uint256 public constant LIQUIDATION_BONUS = 10;

    constructor(address _usdc, AggregatorV3Interface _priceFeedETH) {
        usdc = IERC20(_usdc);
        priceFeedETH = _priceFeedETH;
    }

    event borrowed(address indexed user, uint256 amount);
    event deposited(address indexed user, uint256 amount);
    event withdrawn(address indexed user, uint256 amount);
    event Liquidated(address indexed borrower,address indexed liquidator,uint256 repaidAmount,uint256 collateralSeized);

    struct User {
        uint256 collateralisedETH;
        uint256 lendedUSDC;
        uint256 lastTransactionTime;
    }

    mapping(address => User) private users;

    function ETHPrice() public view returns (uint256) {
        (, int256 price, , , ) = priceFeedETH.latestRoundData();
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

    function liquidate(address borrower) public {
        User storage user = users[borrower];
        require(user.lendedUSDC > 0);
        uint256 collateralRatio = getCollateralRatio(borrower);
        require(collateralRatio < LIQUIDATION_THRESHOLD);

        uint256 debt = user.lendedUSDC;
        uint256 collateralValue = (user.collateralisedETH * ETHPrice()) / 1e18;
        uint256 bonusCollateral = (debt * LIQUIDATION_BONUS) / 100;
        uint256 totalCollateralSeized = debt + bonusCollateral;

        require(totalCollateralSeized <= collateralValue);

        usdc.transferFrom(msg.sender, address(this), debt);
        user.lendedUSDC = 0;
        user.collateralisedETH -= totalCollateralSeized;
        payable(msg.sender).transfer(totalCollateralSeized);

        emit Liquidated(borrower, msg.sender, debt, totalCollateralSeized);
    }

    function getCollateralBalance(address user) public view returns (uint256) {
        return users[user].collateralisedETH;
    }

    function getDebt(address user) public view returns (uint256) {
        return users[user].lendedUSDC;
    }
}