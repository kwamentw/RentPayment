// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {RentPayment} from "../src/Rent.sol";

contract deployRent is Script{
    RentPayment rent;

    function run() public returns(RentPayment){
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY"); 
        vm.startBroadcast(deployerPrivateKey);
        rent = new RentPayment();
        vm.stopBroadcast();

        return rent;
    }
}