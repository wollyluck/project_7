
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
            
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false);
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
      
  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false);

      let reverted = false;
      try 
      {
          await config.flightSurety.setTestingMode(true);
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");      

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);

  });

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    
    // ARRANGE
    let newAirline = accounts[2];

    // ACT
    try {
        await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
    }
    catch(e) {

    }
    let result = await config.flightSuretyData.isRegistered.call(newAirline); 

    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });


  it('(airline) Register first 4 airlines without consensus', async () => {
    
    // ARRANGE
    let airline = accounts[2];
    let airline3 = accounts[3];
    let airline4 = accounts[4];
    
    
    // ACT
    try {
        await config.flightSuretyApp.registerAirline(airline3, config.firstAirline);
        await config.flightSuretyApp.registerAirline(airline4, config.firstAirline);

    }
    catch(e) {

    }
    let result1 = await config.flightSuretyData.isRegistered.call(airline3); 
    let result2 = await config.flightSuretyData.isRegistered.call(airline4); 
    // ASSERT
    assert.equal(result1, true, "Airline 3 cannot be registered.");
    assert.equal(result2, true, "Airline 4 cannot be registered.");

    
  });

  it('(airline) Register 5th airline. Multi-party consensus test - Registration success', async () => {
    
    // ARRANGE
    let airline1 = config.firstAirline;
    let airline2 = accounts[2];
    let airline3 = accounts[3];
    let airline4 = accounts[4];
    let airline5 = accounts[6];
    // ACT
    let reverted = false;
    try {
        await config.flightSuretyApp.registerAirline(airline5, airline3);
        await config.flightSuretyApp.registerAirline(airline5, airline4);
    }
    catch(e) {

      reverted = true;
    }
    let result = await config.flightSuretyData.isRegistered.call(airline5); 
   

    // ASSERT
    assert.equal(result, true, "Error adding 5th Airline with consensus");

  });
 
  it('(airline) Register 5th airline. Multi-party consensus test - Registration fail', async () => {
    
    // ARRANGE
    let airline1 = config.firstAirline;
    let airline2 = accounts[2];
    let airline3 = accounts[3];
    let airline4 = accounts[4];
    let airline5 = accounts[5];

    // ACT
    try {
        await config.flightSuretyApp.registerAirline(airline5, airline1);
    }
    catch(e) {
        console.log(e);
    }
    let result = await config.flightSuretyData.isRegistered.call(airline5); 

    // ASSERT
    assert.equal(result, false, "5th Airline cannot be added without consensus");

  });   
 

});
