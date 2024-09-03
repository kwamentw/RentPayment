// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {CheckPrice} from "./pricefeed.sol";

contract RentPayment{
    CheckPrice usdprice;

    event NewTenantAdded(address newtenant);
    event TenantSacked(address tenant);
    event AddressesShouldPayTheirRent();
    event landlordChanged(address,address);
    event rentPayed(address tenant, uint256 nextPaymentTime,uint256 amount);
    event RentWithdrawed(address landlord);

    error alreadyTenant();
    error invalidTenant();
    error RentNotExpired();
    error insufficientAmount();

    address payable landlord;
    uint256 RENT_COST = 0.03e18;
    uint256 internal tenantsTotal;
    mapping (address tenant => uint256 roomId) tenantDetails;
    mapping (address tenant => uint256 timeRentPayed) paymentRecords;

    constructor(){
        landlord = payable(msg.sender);
    }
    modifier onlyLandlord {
        require(msg.sender == landlord,"only landlord can perform this");
        _;
    }

    receive()external payable{}

    /**
     * Owner adds a new Tenant
     * @param newTenant address of new tenant
     * @param roomNumber room number of tenant
     */
    function addTenant(address newTenant, uint256 roomNumber) external onlyLandlord{
        if (tenantDetails[newTenant] != 0){ revert alreadyTenant();}
        emit NewTenantAdded(newTenant);
        tenantsTotal += 1;
        tenantDetails[newTenant]=roomNumber;
        paymentRecords[newTenant] = block.timestamp;
    }

    function removeTenant(address tenant) external onlyLandlord{
        if(tenantDetails[tenant] == 0){revert invalidTenant();}
        emit TenantSacked(tenant);
        tenantsTotal -= 1;
        delete tenantDetails[tenant];
        delete paymentRecords[tenant];
    }

    function checkOwing(address tenant) public view returns(address){
        if(tenantDetails[tenant] == 0){revert invalidTenant();}
        if (paymentRecords[tenant] + 30 days > block.timestamp){revert RentNotExpired();}
        return tenant;
    }

    function checkOwingBatch(address[] memory tenants) external onlyLandlord returns(address[] memory tenantsOwing){
        uint256 length = tenants.length;
        for(uint256 i=0; i<length; i++){
            tenantsOwing[i]=checkOwing(tenants[i]);
        }
        emit AddressesShouldPayTheirRent();
    }

    function payRent() external payable returns(bool){
        if(tenantDetails[msg.sender] == 0){revert invalidTenant();}
        if(msg.value != RENT_COST){revert insufficientAmount();}
        checkOwing(msg.sender);

        uint256 amountPaid = msg.value;

        paymentRecords[msg.sender]=block.timestamp;

        if(amountPaid > RENT_COST){
            (bool sent,) = payable(msg.sender).call{value: amountPaid - RENT_COST}("");
            require(sent);
        }
        payable(landlord).transfer(RENT_COST);

        emit rentPayed(msg.sender,block.timestamp,address(this).balance);

        return true;
    }

    function checkRentInUSD(uint256 amountInETH) external view returns(uint256 amoutInUSd){
        return (uint256(usdprice.currentRate()) * amountInETH)/1e26;
    }

    function changeLandlord(address newlandlord) external onlyLandlord{
        address oldlandlord = landlord;
        landlord = payable(newlandlord);

        emit landlordChanged(oldlandlord,landlord);
    }

    function checkTotalRentReceived() public view returns(uint256){
        return address(this).balance;
    }
    function totalTenants() external view returns(uint256){
        return tenantsTotal;
    }
    function getlandlord() external view returns(address){
        return landlord;
    }
}