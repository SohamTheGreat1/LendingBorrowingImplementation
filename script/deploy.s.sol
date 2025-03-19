// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {sAAVE} from "../src/LnB.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract deploySAave is Script {
    function run() external returns(sAAVE){
        vm.startBroadcast();
        address usdcAddress = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address ethPriceFeedAddress = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

        sAAVE sAave = new sAAVE(usdcAddress, AggregatorV3Interface(ethPriceFeedAddress));
        vm.stopBroadcast();
        return sAave;
    }
}

