// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {CheckPrice} from "../src/pricefeed.sol";
import {RentPayment} from "../src/Rent.sol";
import {console2} from "forge-std/console2.sol";

contract MainTest is Test{
    CheckPrice pricechecker;
    RentPayment rent;

    receive() external payable{}

    function setUp() public {
        pricechecker = new CheckPrice(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        rent = new RentPayment();
    }

    function testRate() public view{
        int price = pricechecker.currentRate();
        console2.log("Current rate is: ",price);
    }

    function addApartment() public {
        rent.addNewApartment(4,true,false,2);
        rent.addNewApartment(1,false,true,10);
        rent.addNewApartment(2, true, false,3);
    }

    function testAddApartment() public {

        addApartment();

        uint256 arrayLen = rent.getApartmentTypes().length;
        assertEq(arrayLen,3);
    }

    function testRemoveApartment() public {
        addApartment();
        uint256 arrayLen = rent.getApartmentTypes().length;
        console2.log("Number of rooms added",arrayLen);

        rent.removeApartment(1);
        assertEq(rent.getApartmentTypes().length,2);
    }

    function testUpdateApartmentAvailability() public {
        addApartment();
        rent.updateApartments(2,52);
        assertEq(rent.getApartment(2).noOfApartmentsAvailable,52);
    }

    function testCheckApartmentAvailable() public {
        addApartment();
        (uint256 available,uint256 id)=rent.checkApartmentsAvailable(1);
        assertGt(id,0);
        assertEq(available,10);
    }

    function testAddTenant() public {
        addApartment();

        uint256[] memory typeOfAptmnt = new uint256[](3);
        uint256[] memory apartmentIds = new uint256[](3);
        uint256[] memory timeDueRent = new uint256[](3);
        uint256[] memory botOrRent = new uint256[](3);

        uint256 timeDue = block.timestamp;

        typeOfAptmnt[0]=1;
        typeOfAptmnt[1]=0;
        typeOfAptmnt[2]=2;

        apartmentIds[0]=1;
        apartmentIds[1]=2;
        apartmentIds[2]=3;

        timeDueRent[0]=timeDue;
        timeDueRent[1]=timeDue;
        timeDueRent[2]=timeDue;


        botOrRent[0]=1;
        botOrRent[1]=0;
        botOrRent[2]=1;

        rent.addTenant(address(45),typeOfAptmnt,apartmentIds,timeDueRent,botOrRent);
        rent.addTenant(address(46),typeOfAptmnt,apartmentIds,timeDueRent,botOrRent);
        rent.addTenant(address(47),typeOfAptmnt,apartmentIds,timeDueRent,botOrRent);
        //TODO: assert the apartments os tenant
        assertEq(rent.tenantsTotal(),3);
    }

    // function addtenants() public{
    //     rent.addTenant(address(0xabc),11);
    //     // rent.addTenant(address(0xddcde),7);
    //     // rent.addTenant(address(333),21);
    //     // rent.addTenant(address(454),9);
    // }

    // function testAddtenant() public  {
    //     rent.addTenant(address(0xabc),11);
    //     rent.addTenant(address(333),21);
    //     assertEq(rent.totalTenants(),2);
    // }

    // function testEvictTenant() public {
    //     addtenants();
    //     rent.removeTenant(address(333));
    //     assertEq(rent.totalTenants(),3);
    // }

    // function testCheckOwing() public {
    //     rent.addTenant(address(0xddcde),7);
    //     vm.warp(block.timestamp + 33 days);
    //     rent.checkOwing(address(0xddcde));
    // }

    // function testPayRent() public {
    //     addtenants();
    //     vm.deal(address(0xabc),1 ether);
    //     vm.startPrank(address(0xabc));
    //     vm.warp(block.timestamp + 33 days);
    //     assertTrue(rent.payRent{value: 0.03e18}());
    //     console2.log(address(rent.getlandlord()).balance);
    //     vm.stopPrank();
    // }

    // function testWithdrawRent() public {
    //     addtenants();
    //     vm.deal(address(333),1 ether);
    //     vm.prank(address(333));
    //     vm.warp(block.timestamp + 33 days);
    //     rent.payRent{value: 0.03e18 }();

    //     vm.deal(address(454),2e18);
    //     vm.prank(address(454));
    //     vm.warp(block.timestamp + 33 days);
    //     rent.payRent{value: 0.03 ether}();

    //     vm.deal(address(0xddcde),1e18);
    //     vm.prank(address(0xddcde));
    //     vm.warp(block.timestamp + 33 days);
    //     rent.payRent{value: 0.03e18}();

    //     uint256 bal = address(rent).balance;

    //     rent.changeLandlord(address(223));

    //     vm.prank(address(223));
    //     rent.withdrawRent();
    //     assertEq(address(rent.getlandlord()).balance , bal);
    // }

    function testCheckAmtUsd() public view {
        assertGt(rent.checkRentInUSD(56.778e18),0);
    }

}