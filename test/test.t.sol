// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {sAAVE} from "../src/LnB.sol";
import {deploySAave} from "../script/deploy.s.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract sAAVEInvarianceTest is Test {
    sAAVE public sAave;
    address public USER = makeAddr("user");
    address public LIQUIDATOR = makeAddr("liquidator");
    address public usdcAddress = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public ethPriceFeedAddress = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

    function setUp() public {
        sAave = new sAAVE(usdcAddress, AggregatorV3Interface(ethPriceFeedAddress));
        vm.deal(USER, 1000 ether);
    }

    function testDeposit() public {
        sAave.depositCollateral{value: 10 ether}();
        assertEq(sAave.getCollateralBalance(USER), 10 ether);
    }

    function testWithdraw() public {
        vm.prank(USER);
        sAave.depositCollateral{value: 10 ether}();

        vm.prank(USER);
        sAave.withdrawCollateral(5 ether);
        assertEq(sAave.getCollateralBalance(USER), 5 ether);
    }

    function testBorrow() public {
        vm.prank(USER);
        sAave.depositCollateral{value: 10 ether}();

        vm.prank(USER);
        sAave.borrow(1000 * 1e6); // Borrowing 1000 USDC
        assertEq(sAave.getDebt(USER), 1000 * 1e6);
    }

    function testRepay() public {
        vm.prank(USER);
        sAave.depositCollateral{value: 10 ether}();
        vm.prank(USER);
        sAave.borrow(1000 * 1e6);

        vm.prank(USER);
        sAave.repayLoan(1000 * 1e6);
        assertEq(sAave.getDebt(USER), 0);
    }

    function testLiquidate() public {
        vm.prank(USER);
        sAave.depositCollateral{value: 10 ether}();
        vm.prank(USER);
        sAave.borrow(5000 * 1e6); 


        vm.prank(LIQUIDATOR);
        sAave.liquidate(USER);

        assertEq(sAave.getCollateralBalance(USER), 0);
        assertEq(sAave.getDebt(USER), 0);
    }
}