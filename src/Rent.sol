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
    // landlord address
    address landlord;
    // TO BE CHECKED
    uint256 RENT_COST = 0.03e18;
    // security deposit when renting a unit 
    uint256 SEC_DEPOSIT=0.00003e18;
    // total number of tenants
    uint256 internal tenantsTotal;
//-----------------------------------------------------------------------
    // apartments owned or rented by tenant
    mapping (address tenant => uint256[] apartmentID) tenantDetails;
    // payment records
    mapping (address tenant => uint256[] timeRentPayed) paymentRecords;
    // info on mode of acquisition on a specific apartment
    mapping(uint256 _apartmentID => ModeOfAcquisition mode) acquireInfo;
    // owner info | might take od units acquired later since apatmentID can track units bought | we might just analyse it from there
    mapping(uint256 _apartmentID=>uint256 _unitTypeId) ownershipInfo;
//-----------------------------------------------------------------------

// To tell whether its a rental or bought 
enum ModeOfAcquisition{
    Buy,
    Rent
}

struct UnitInfo{
    // index of the unit type added
    uint256 unitTypeId;
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
    function addNewUnit(uint256 _noOfRooms, bool _selfContain, bool _bigger, uint256 _numAvailable) external onlyLandlord returns(UnitInfo memory){
        require(_noOfRooms != 0,"invalidUnitType");
        // add check to make sure one type cannot be added multiple times
        UnitInfo memory tempUnit = UnitInfo({
            unitTypeId: totalNoOfUnitTypes++,
            noOfRooms: _noOfRooms,
            selfContain: _selfContain,
            bigger: _bigger,
            noOfUnitsAvailable: _numAvailable
        });

        typeOfUnit.push(tempUnit);

        return tempUnit;
    }

    /**
     * Remove a type of unit that is being put up for rent
     * @param _unitTypeId the index of the unit type to remove
     */
    function removeUnit(uint256 _unitTypeId) external onlyLandlord {
        // we can remove units when there are available units of not FYI landlord is trusted
        // Available rooms can be undergoing renovation hence not making them accessible eventhoguh they are availble 
        require(typeOfUnit[_unitTypeId].noOfRooms != 0,"InvalidUnitType");
        delete typeOfUnit[_unitTypeId];
    }

    /**
     * A function to update type of units available in system.
     * @param _unitTypeId Type of unit to update
     * @param unitsAvailable number of units available 
     */
    function updateUnits(uint256 _unitTypeId, uint256 unitsAvailable) external onlyLandlord{
        typeOfUnit[_unitTypeId].noOfUnitsAvailable = unitsAvailable; 
    }

    /**
     * Check the number of rooms specification to see if there is a match to preference
     * And whether there are some units available
     * @param _numOfRooms number of rooms Tenant is looking for 
     */
    function checkUnitsAvailable(uint256 _numOfRooms) external view returns (uint256 unitsAvailable, uint256 uintID ){
        // user can specify preferable number of rooms in the unit he looking for to know how many are available
        for(uint256 i=0; i<typeOfUnit.length; i++){
            if(typeOfUnit[i].noOfRooms == _numOfRooms){
                return (typeOfUnit[i].noOfUnitsAvailable, typeOfUnit[i].unitTypeId);
            }
        }

    }

    /**
     * 
     * @param newTenant address of new tenant to be added
     * @param _typeOfUnit type of apartment Tenant acquired
     * @param _apartmentIds Id of apartments acquire by tenant / it can be one or more 
     * @param _paymentTime time payment was made | current payment status
     * @param boughtOrRented way of acquisition | 0 for buy, 1 for rent
     */

    //add a function to handle single adds and loop over that function for this function to make it add for multiple 
    function addTenant(address newTenant,uint256[] memory _typeOfUnit, uint256[] memory _apartmentIds, uint256[] memory _paymentTime, uint256[] memory boughtOrRented) external onlyLandlord{
        if (paymentRecords[newTenant].length != 0){ revert alreadyTenant();}
        require(_apartmentIds.length == _paymentTime.length, "invalidInput");
        require(_apartmentIds.length == boughtOrRented.length, "InvalidEnumInput");
        emit NewTenantAdded(newTenant);
        tenantsTotal += 1;
        //////
        tenantDetails[newTenant]=_apartmentIds;
        uint256 apartmentLength = _apartmentIds.length;
        for(uint256 i=0; i<apartmentLength; ++i){
            _paymentTime[i] = block.timestamp;
            ownershipInfo[_apartmentIds[i]]=_typeOfUnit[i];
            acquireInfo[_apartmentIds[i]] = boughtOrRented[i]==0 ? ModeOfAcquisition.Buy:ModeOfAcquisition.Rent;
        }
        paymentRecords[newTenant] = _paymentTime;
    }


    /**
     * Function to call when sacking tenant
     * @param tenant address of tenant to remove
     * @param _apartmentId apartment Id to remove
     */
    function removeTenant(address tenant, uint256 _apartmentId) external onlyLandlord{
        if(tenantDetails[tenant].length == 0){revert invalidTenant();}
        emit TenantSacked(tenant);
        tenantsTotal -= 1;
        delete tenantDetails[tenant];
        delete paymentRecords[tenant];
        delete acquireInfo[_apartmentId];
        delete ownershipInfo[_apartmentId];
    }

    /**
     * Checks whether tenant is owing rent or not
     * @param tenant address of tenant
     */
    function checkOwing(address tenant) public view returns(address){
        if(tenantDetails[tenant].length == 0){revert invalidTenant();}
        //must loop over this if more than one apartment
        // if (paymentRecords[tenant] + 30 days > block.timestamp){revert RentNotExpired();}
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
        if(tenantDetails[msg.sender].length == 0){revert invalidTenant();}
        if(msg.value != RENT_COST){revert insufficientAmount();}
        checkOwing(msg.sender);

        // loop over this if more than one apartment
        // paymentRecords[msg.sender]=block.timestamp;

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