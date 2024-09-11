// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {CheckPrice} from "./pricefeed.sol";

contract RentPayment{
    CheckPrice usdprice;
//--------------------------- EVENTS ---------------------------------
    event NewTenantAdded(address newtenant);
    event TenantSacked(address tenant);
    event AddressesShouldPayTheirRent();
    event landlordChanged(address,address);
    event rentPayed(address tenant, uint256 nextPaymentTime);
    event RentWithdrawed(address landlord);
//------------------------------ ERRORS -------------------------------
    error alreadyTenant();
    error invalidTenant();
    error RentNotExpired();
    error insufficientAmount();

    address landlord;
    uint256 RENT_COST = 0.03e18;
    uint256 internal tenantsTotal;
    mapping (address tenant => uint256 roomId) tenantDetails;
    mapping (address tenant => uint256 timeRentPayed) paymentRecords;

    constructor(){
        landlord = msg.sender;
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

    /**
     * Removes tenant
     * @param tenant address of tenant
     */
    function removeTenant(address tenant) external onlyLandlord{
        if(tenantDetails[tenant] == 0){revert invalidTenant();}
        emit TenantSacked(tenant);
        tenantsTotal -= 1;
        delete tenantDetails[tenant];
        delete paymentRecords[tenant];
    }

    /**
     * Checks whether tenant is owing rent or not
     * @param tenant address of tenant
     */
    function checkOwing(address tenant) public view returns(address){
        if(tenantDetails[tenant] == 0){revert invalidTenant();}
        if (paymentRecords[tenant] + 30 days > block.timestamp){revert RentNotExpired();}
        return tenant;
    }

   /**
    * Check owing for batch of address
    * @param tenants batch of tenants address
    */
    function checkOwingBatch(address[] memory tenants) external onlyLandlord returns(address[] memory tenantsOwing){
        uint256 length = tenants.length;
        for(uint256 i=0; i<length; i++){
            tenantsOwing[i]=checkOwing(tenants[i]);
        }
        emit AddressesShouldPayTheirRent();
    }

    /**
     * Tenants call this to pay rent
     * Amount to be payed cannot be more than rent cost
     */
    function payRent() external payable returns(bool){
        if(tenantDetails[msg.sender] == 0){revert invalidTenant();}
        if(msg.value != RENT_COST){revert insufficientAmount();}
        checkOwing(msg.sender);

        paymentRecords[msg.sender]=block.timestamp;

        emit rentPayed(msg.sender,block.timestamp);

        return true;
    }

    /**
     * converts eth to dollars
     * @param amountInETH eth amount to convert
     * Helps tenants know how much they are spending
     */
    function checkRentInUSD(uint256 amountInETH) external view returns(uint256 amoutInUSd){
        return (uint256(usdprice.currentRate()) * amountInETH)/1e26;
    }

    /**
     * Only Landlord can execute this to withdraw all the rent saved in the contract
     */
    function withdrawRent() external onlyLandlord{
        uint256 amountToWithdraw = checkTotalRentReceived();
        (bool sent,)=payable(landlord).call{value:amountToWithdraw}("");
        require(sent);
        emit RentWithdrawed(landlord);
    }

    /**
     * call to change landlord in case of sale of property
     * @param newlandlord address of new landlord
     */
    function changeLandlord(address newlandlord) external onlyLandlord{
        address oldlandlord = landlord;
        landlord = newlandlord;

        emit landlordChanged(oldlandlord,landlord);
    }

    /**
     * Returns how much rent is stored in contract
     */
    function checkTotalRentReceived() public view returns(uint256){
        return address(this).balance;
    }
    /**
     * Returns total number of tenants
     */
    function totalTenants() external view returns(uint256){
        return tenantsTotal;
    }
    /**
     * Returns address of landlord
     */
    function getlandlord() external view returns(address){
        return landlord;
    }
}