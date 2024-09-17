// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {CheckPrice} from "./pricefeed.sol";

contract RentPayment{
    // price oracle
    CheckPrice usdprice;
//--------------------------- EVENTS ------------------------------------
    event NewTenantAdded(address newtenant);
    event TenantSacked(address tenant);
    event AddressesShouldPayTheirRent();
    event landlordChanged(address,address);
    event rentPayed(address tenant, uint256 nextPaymentTime);
    event RentWithdrawed(address landlord);
//------------------------------ ERRORS ---------------------------------
    error alreadyTenant();
    error invalidTenant();
    error RentNotExpired();
    error insufficientAmount();
//-----------------------------------------------------------------------
    address landlord;
    uint256 RENT_COST = 0.03e18;
    uint256 SEC_DEPOSIT=0.00003e18;
    uint256 internal tenantsTotal;
//-----------------------------------------------------------------------
    mapping (address tenant => uint256 roomId) tenantDetails;
    mapping (address tenant => uint256 timeRentPayed) paymentRecords;
//-----------------------------------------------------------------------

struct UnitInfo{
    // index of the unit type added
    uint256 unitTypeIndex;
    // number of rooms a unit has from single room to 5 bedroom units
    uint256 noOfRooms;
    // it is either self contain or shared hall or washrooms 
    bool selfContain;
    // they are either bigger apartments or small
    bool bigger;
    // number of units available
    uint256 noOfUnitsAvailable;
}

// Type of units for rent or sale
UnitInfo[] public typeOfUnit;
// The total number of the types of units added by the Landlord
uint256 totalNoOfUnitTypes;

    constructor(){
        landlord = msg.sender;
    }
    /**
     * makes sure only landlord can call functions that apply this modifier
     */
    modifier onlyLandlord {
        require(msg.sender == landlord,"only landlord can perform this");
        _;
    
    }

    /**
     * Add a new type of unit that is a availiable for rent
     * @param _noOfRooms number of rooms of new unit 
     * @param _selfContain is it a self contain unit or it is shared
     * @param _bigger is it the bigger unit if yes true otherwise, False
     * @param _numAvailable Number of units available for the unit type to be added 
     */
    function addNewUnit(uint256 _noOfRooms, bool _selfContain, bool _bigger, uint256 _numAvailable) external onlyLandlord returns(bytes memory){
        require(_noOfRooms != 0,"invalidUnitType");
        // add check to make sure one type cannot be added multiple times
        UnitInfo memory tempUnit = UnitInfo({
            unitTypeIndex: totalNoOfUnitTypes++,
            noOfRooms: _noOfRooms,
            selfContain: _selfContain,
            bigger: _bigger,
            noOfUnitsAvailable: _numAvailable
        });

        typeOfUnit.push(tempUnit);
    }

    /**
     * Remove a type of unit that is being put up for rent
     * @param _unitTypeIndex the index of the unit type to remove
     */
    function removeUnit(uint256 _unitTypeIndex) external onlyLandlord {
        // we can remove units when there are available units of not FYI landlord is trusted
        // Available rooms can be undergoing renovation hence not making them accessible eventhoguh they are availble 
        require(typeOfUnit[_unitTypeIndex].noOfRooms != 0,"InvalidUnitType");
        delete typeOfUnit[_unitTypeIndex];
    }

    /**
     * Check the number of rooms specification to see if there is a match to preference
     * And whether there are some units available
     * @param _numOfRooms number of rooms Tenant is looking for 
     */
    function checkUnitsAvailable(uint256 _numOfRooms) external view returns (uint256 unitsAvailable){
        // user can specify preferable number of rooms in the unit he looking for to know how many are available
        for(uint256 i=0; i<typeOfUnit.length; i++){
            if(typeOfUnit[i].noOfRooms == _numOfRooms){
                return typeOfUnit[i].noOfUnitsAvailable;
            }
        }

    }

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

/**
 * Features to add
 * One person can own multiple units(buy, rent, sell, remove)
 * add specification for the type of unit
 * (different types of unit for eg. single room, two bedrooms, studio apartment)
 * add buy option instead of renting
 * Add some discount feature to run promo when selling
 */