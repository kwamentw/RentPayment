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
    event RentNotDue(address,uint256);
    event RentWithdrawed(address landlord);
//------------------------------ ERRORS ---------------------------------
    error alreadyTenant();
    error invalidTenant();
    error InvalidInput();
    error RentNotExpired();
    error ApartmentIsBought(uint256 id);
    error insufficientAmount();
//-----------------------------------------------------------------------
    // landlord address
    address landlord;
    // TO BE CHECKED
    uint256 RENT_COST = 0.03e18;
    // security deposit when renting a Apartment 
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
    // owner info | might take od Apartments acquired later since apatmentID can track Apartments bought | we might just analyse it from there
    mapping(uint256 _apartmentID=>uint256 _ApartmentTypeId) ownershipInfo;
//-----------------------------------------------------------------------

// To tell whether its a rental or bought 
enum ModeOfAcquisition{
    Buy,
    Rent
}

struct ApartmentInfo{
    // index of the Apartment type added
    uint256 ApartmentTypeId;
    // number of rooms a Apartment has from single room to 5 bedroom Apartments
    uint256 noOfRooms;
    // it is either self contain or shared hall or washrooms 
    bool sharedRestroom;
    // they are either biggerSqft apartments or small
    bool biggerSqft;
    // number of Apartments available
    uint256 noOfApartmentsAvailable;
}

// Type of Apartments for rent or sale
ApartmentInfo[]  typeOfApartment;
// The total number of the types of Apartments added by the Landlord
uint256 totalNoOfApartmentTypes;

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
     * Add a new type of Apartment that is a availiable for rent
     * @param _noOfRooms number of rooms of new Apartment 
     * @param _sharedRestroom is it a self contain Apartment or it is shared
     * @param _biggerSqft does it have a bigger area if yes true otherwise, False
     * @param _numAvailable Number of Apartments available for the Apartment type to be added 
     */
    function addNewApartment(uint256 _noOfRooms, bool _sharedRestroom, bool _biggerSqft, uint256 _numAvailable) external onlyLandlord returns(ApartmentInfo[] memory){
        require(_noOfRooms != 0,"invalidApartmentType");
        // add check to make sure one type cannot be added multiple times
        ApartmentInfo memory tempApartment = ApartmentInfo({
            ApartmentTypeId: totalNoOfApartmentTypes++,
            noOfRooms: _noOfRooms,
            sharedRestroom: _sharedRestroom,
            biggerSqft: _biggerSqft,
            noOfApartmentsAvailable: _numAvailable
        });

        typeOfApartment.push(tempApartment);

        return typeOfApartment;
    }

    /**
     * Remove a type of Apartment that is being put up for rent
     * @param _ApartmentTypeId the index of the Apartment type to remove
     */
    function removeApartment(uint256 _ApartmentTypeId) external onlyLandlord {
        // we can remove Apartments when there are available Apartments of not FYI landlord is trusted
        // Available rooms can be undergoing renovation hence not making them accessible eventhoguh they are availble 
        require(typeOfApartment[_ApartmentTypeId].noOfRooms != 0,"InvalidApartmentType");
        delete typeOfApartment[_ApartmentTypeId];
    }

    /**
     * A function to update type of Apartments available in system.
     * @param _ApartmentTypeId Type of Apartment to update
     * @param ApartmentsAvailable number of Apartments available 
     */
    function updateApartments(uint256 _ApartmentTypeId, uint256 ApartmentsAvailable) external onlyLandlord{
        typeOfApartment[_ApartmentTypeId].noOfApartmentsAvailable = ApartmentsAvailable; 
    }

    /**
     * Check the number of rooms specification to see if there is a match to preference
     * And whether there are some Apartments available
     * @param _numOfRooms number of rooms Tenant is looking for 
     */
    function checkApartmentsAvailable(uint256 _numOfRooms) external view returns (uint256 ApartmentsAvailable, uint256 uintID ){
        // user can specify preferable number of rooms in the Apartment he looking for to know how many are available
        for(uint256 i=0; i<typeOfApartment.length; i++){
            if(typeOfApartment[i].noOfRooms == _numOfRooms){
                return (typeOfApartment[i].noOfApartmentsAvailable, typeOfApartment[i].ApartmentTypeId);
            }
        }

    }

    /**
     * 
     * @param newTenant address of new tenant to be added
     * @param _typeOfApartment type of apartment Tenant acquired
     * @param _apartmentIds Id of apartments acquire by tenant / it can be one or more 
     * @param _paymentTime time payment was made | current payment status
     * @param boughtOrRented way of acquisition | 0 for buy, 1 for rent
     */
    function addTenant(address newTenant,uint256[] memory _typeOfApartment, uint256[] memory _apartmentIds, uint256[] memory _paymentTime, uint256[] memory boughtOrRented) external onlyLandlord{
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
            ownershipInfo[_apartmentIds[i]]=_typeOfApartment[i];
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
        require(ownershipInfo[_apartmentId]!=0,"inavlidinput");
        emit TenantSacked(tenant);
        tenantsTotal -= 1;
        delete tenantDetails[tenant];
        delete paymentRecords[tenant];
        delete acquireInfo[_apartmentId];
        delete ownershipInfo[_apartmentId];
    }

    /**
     * Removes a batch of tenants 
     * @param tenant batch of tenants to remove
     * @param _apartmentId batch of apartment ids owned by tenants to remove
     */
    function removeBatchTenants(address[] memory tenant, uint256[] memory _apartmentId) external onlyLandlord{
        for(uint i=0;i<tenant.length;++i){
            tenantsTotal -= 1;
            emit TenantSacked(tenant[i]);
            delete tenantDetails[tenant[i]];
            delete paymentRecords[tenant[i]];
        }

        for(uint i=0; i<_apartmentId.length;++i){
             delete acquireInfo[_apartmentId[i]];
            delete ownershipInfo[_apartmentId[i]];
        }
    }

    /**
     * Checks whether tenant is owing rent or not
     * @param tenant address of tenant
     */
    function checkOwing(address tenant) public returns(address _tenant, uint256[] memory apartmentIndex){

        if(tenantDetails[tenant].length == 0){revert invalidTenant();}

        uint256 recordsLength = paymentRecords[tenant].length;
        uint256[] memory datePayed = paymentRecords[tenant];
        _tenant= tenant;

        for(uint256 i=0; i<recordsLength; i++){
            if((datePayed[i] + 30 days)<block.timestamp){
                apartmentIndex[i] = i;
            }else{
                emit RentNotDue(tenant,i);
            }
        }
    }

    /**
     * Tenants call this to pay rent
     * Amount to be payed cannot be more than rent cost
     */
    function payRent() external payable returns(bool){
        if(tenantDetails[msg.sender].length == 0){revert invalidTenant();}
        
        uint256[] memory _ownerapartmentIds = tenantDetails[msg.sender];
        uint256[] memory idNextRentDue;

        (,_ownerapartmentIds)=checkOwing(msg.sender);
        uint256 ownerApartmentsLen = _ownerapartmentIds.length;

        require(ownerApartmentsLen !=0,"DoesNotOwe");

        for(uint256 i=0; i<ownerApartmentsLen; i++){
            if(msg.value < RENT_COST){revert insufficientAmount();}
            if(acquireInfo[_ownerapartmentIds[i]] == ModeOfAcquisition.Buy){revert ApartmentIsBought(_ownerapartmentIds[i]);}
            msg.value - RENT_COST;
            idNextRentDue[i]=block.timestamp;
        }
        require(idNextRentDue.length == ownerApartmentsLen, "MismatchBTNOwnerAptmntLen");

        paymentRecords[msg.sender]=idNextRentDue;

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

    /**
     * Returns all the types of apartment in the system 
     */
    function getApartmentTypes() public view returns(ApartmentInfo[] memory){
        return typeOfApartment;
    }
}