pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false

    mapping (address => Airline) RegisteredAirlines;
    mapping (bytes32 => address[]) AirlineInsurees;
    mapping (address => mapping(bytes32 => uint)) InsuredAmounts;
    mapping (bytes32 => mapping(address => uint)) InsuredPayouts;
    mapping (address => uint) InsurancePayments;
    mapping(address => uint) private accountBalance;
    mapping (address => uint) FundedAirlineAmount;
    mapping (address => uint) authorizedContracts;

    address[] airlines;



    struct Airline 
    {
        address airlineAddress;
        bool isRegistered;
        bool isFunded;
    }



    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                    address firstAirline
                                ) 
                                public 
    {
        contractOwner = msg.sender;
        RegisteredAirlines[firstAirline].isRegistered = true;
        RegisteredAirlines[firstAirline].isFunded = false;
        airlines.push(firstAirline);
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireRegisteredAirline(address _airline)
    {
        require(RegisteredAirlines[_airline].isRegistered == true, "The airline is not registered");
        _;
    }

    modifier requireFundedAirline(address _airline)
    {
        require(RegisteredAirlines[_airline].isFunded == true, "The airline is not funded");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    


    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            requireContractOwner 
    {
        operational = mode;
    }

    function isRegistered (address _airplane) public view returns(bool)
    {
        return RegisteredAirlines[_airplane].isRegistered;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    function authorizeCaller
                            (
                                address _contractAddress
                            )
                            external
                            requireContractOwner
    {
        authorizedContracts[_contractAddress] = 1;

    }
    
    
    

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline(address _airline, address _caller) external requireIsOperational
                                                                            requireRegisteredAirline(_caller)
                                                                            returns (bool success)
    {
        RegisteredAirlines[_airline] = Airline({airlineAddress: _airline, isRegistered: true, isFunded: false});
        airlines.push(_airline);
        success = true;
        return (success);
    }
    
    

   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buyInsurance (address _airline, string _flight, uint _timestamp, address _passenger, uint _amount) external
                                                                                                                            payable
    {
       bytes32 flightkey = getFlightKey(_airline, _flight, _timestamp);

        AirlineInsurees[flightkey].push(_passenger);
        InsuredAmounts[_passenger][flightkey] = _amount;
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees (address _airline, string _flight, uint _timestamp, uint factor_numerator, uint factor_denominator) 
                                                                                                        external  requireIsOperational
    {
        bytes32 flightkey = getFlightKey(_airline, _flight, _timestamp);

        address[] storage insurees = AirlineInsurees[flightkey];
        
        

        for (uint i = 0; i < insurees.length; i++) {
            address passenger = insurees[i];
            uint amountDeposited = InsuredAmounts[passenger][flightkey];
            
            uint amountToPayout = amountDeposited.mul(factor_numerator).div(factor_denominator);
            InsuredPayouts[flightkey][passenger]= amountToPayout;

            InsurancePayments[passenger] += amountToPayout;

        }

    }


    function getPassengerFunds(address _passenger)
                external
                view
                returns(uint) 


    {
        
        return accountBalance[_passenger];
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function withdraw (address _passenger) external payable requireIsOperational
    {
        require (InsurancePayments[_passenger] > 0, "No Insurace Payment");
        uint amountToPayout = InsurancePayments[_passenger];
        InsurancePayments[_passenger] = 0;
        _passenger.transfer(amountToPayout);
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fundAirline (address _airline, uint _amount) public payable requireIsOperational
                                                                    requireRegisteredAirline(_airline)
    {
        require(RegisteredAirlines[_airline].isRegistered = true, "Not Registered");
        FundedAirlineAmount[_airline] += _amount;
        RegisteredAirlines[_airline].isFunded = true;
    }

function getAirlines()
                external
                view
                returns(address[]) 


    {
        return airlines;
    }

function getFlightKey
                        (
                            address airline,
                            string flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }
    


    function getRegisteredAirlineCount() view external returns(uint)
    {
        return airlines.length;
    }

    function receive() public payable requireIsOperational
    {

    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() 
                            external 
                            payable 
    {
       receive();
    }


}

