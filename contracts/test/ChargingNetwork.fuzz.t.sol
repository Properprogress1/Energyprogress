// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ChargingNetwork.sol";
import "../src/IChargingNetwork.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 1000000 * 10**18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract ChargingNetworkFuzzTest is Test {
    ChargingNetwork public chargingNetwork;
    MockERC20 public paymentToken;
    
    address public owner;
    address public operator1;
    address public user1;
    uint256 public stationId1;
    
    uint256 constant LATITUDE_SCALE = 1e6;
    uint256 constant LONGITUDE_SCALE = 1e6;
    uint256 constant ENERGY_SCALE = 1e18;
    uint256 constant PRICE_SCALE = 1e18;

    function setUp() public {
        owner = address(this);
        operator1 = address(0x1);
        user1 = address(0x2);
        
        paymentToken = new MockERC20();
        chargingNetwork = new ChargingNetwork(owner);
        
        chargingNetwork.authorizeOperator(operator1);
        paymentToken.mint(user1, 1000000 * 10**18);
        
        vm.startPrank(operator1);
        stationId1 = chargingNetwork.registerStation(
            40712345,
            -74004567,
            50 * 10**18,
            20 * 10**16,
            IChargingNetwork.EnergySource.Solar,
            7 * 10**18,
            address(paymentToken)
        );
        vm.stopPrank();
    }

    // Fuzz tests for energy consumption
    function testFuzz_RecordEnergyConsumption(uint256 energy) public {
        vm.assume(energy > 0 && energy <= 1000 * ENERGY_SCALE); // Reasonable bounds
        
        vm.startPrank(user1);
        uint256 sessionId = chargingNetwork.startSession(stationId1);
        chargingNetwork.recordEnergyConsumption(sessionId, energy);
        vm.stopPrank();
        
        IChargingNetwork.Session memory session = chargingNetwork.getSession(sessionId);
        assertEq(session.energyConsumed, energy);
    }

    function testFuzz_Revert_RecordEnergyConsumption_ZeroEnergy(uint256 energy) public {
        vm.assume(energy == 0);
        
        vm.startPrank(user1);
        uint256 sessionId = chargingNetwork.startSession(stationId1);
        vm.expectRevert("Energy must be positive");
        chargingNetwork.recordEnergyConsumption(sessionId, energy);
        vm.stopPrank();
    }

    function testFuzz_MultipleEnergyConsumptions(uint256 energy1, uint256 energy2, uint256 energy3) public {
        vm.assume(energy1 > 0 && energy1 <= 500 * ENERGY_SCALE);
        vm.assume(energy2 > 0 && energy2 <= 500 * ENERGY_SCALE);
        vm.assume(energy3 > 0 && energy3 <= 500 * ENERGY_SCALE);
        
        vm.startPrank(user1);
        uint256 sessionId = chargingNetwork.startSession(stationId1);
        chargingNetwork.recordEnergyConsumption(sessionId, energy1);
        chargingNetwork.recordEnergyConsumption(sessionId, energy2);
        chargingNetwork.recordEnergyConsumption(sessionId, energy3);
        vm.stopPrank();
        
        IChargingNetwork.Session memory session = chargingNetwork.getSession(sessionId);
        assertEq(session.energyConsumed, energy1 + energy2 + energy3);
    }

    // Fuzz tests for station pricing
    function testFuzz_UpdateStationPrice(uint256 newPrice) public {
        vm.assume(newPrice > 0 && newPrice <= 1000 * PRICE_SCALE); // Reasonable bounds
        
        vm.startPrank(operator1);
        chargingNetwork.updateStation(stationId1, newPrice, true);
        vm.stopPrank();
        
        IChargingNetwork.Station memory station = chargingNetwork.getStation(stationId1);
        assertEq(station.pricePerKwh, newPrice);
    }

    function testFuzz_Revert_UpdateStationPrice_ZeroPrice(uint256 price) public {
        vm.assume(price == 0);
        
        vm.startPrank(operator1);
        vm.expectRevert("Price must be positive");
        chargingNetwork.updateStation(stationId1, price, true);
        vm.stopPrank();
    }

    // Fuzz tests for station coordinates
    function testFuzz_RegisterStationCoordinates(int256 latitude, int256 longitude) public {
        vm.assume(latitude >= -90 * int256(LATITUDE_SCALE) && latitude <= 90 * int256(LATITUDE_SCALE));
        vm.assume(longitude >= -180 * int256(LONGITUDE_SCALE) && longitude < 180 * int256(LONGITUDE_SCALE));
        
        vm.startPrank(operator1);
        uint256 newStationId = chargingNetwork.registerStation(
            latitude,
            longitude,
            50 * 10**18,
            20 * 10**16,
            IChargingNetwork.EnergySource.Grid,
            7 * 10**18,
            address(paymentToken)
        );
        vm.stopPrank();
        
        IChargingNetwork.Station memory station = chargingNetwork.getStation(newStationId);
        assertEq(station.latitude, latitude);
        assertEq(station.longitude, longitude);
    }

    function testFuzz_Revert_RegisterStationInvalidLatitude(int256 latitude) public {
        vm.assume(latitude < -90 * int256(LATITUDE_SCALE) || latitude > 90 * int256(LATITUDE_SCALE));
        
        vm.startPrank(operator1);
        vm.expectRevert("Invalid latitude");
        chargingNetwork.registerStation(
            latitude,
            -74004567,
            50 * 10**18,
            20 * 10**16,
            IChargingNetwork.EnergySource.Grid,
            7 * 10**18,
            address(paymentToken)
        );
        vm.stopPrank();
    }

    function testFuzz_Revert_RegisterStationInvalidLongitude(int256 longitude) public {
        vm.assume(longitude < -180 * int256(LONGITUDE_SCALE) || longitude >= 180 * int256(LONGITUDE_SCALE));
        
        vm.startPrank(operator1);
        vm.expectRevert("Invalid longitude");
        chargingNetwork.registerStation(
            40712345,
            longitude,
            50 * 10**18,
            20 * 10**16,
            IChargingNetwork.EnergySource.Grid,
            7 * 10**18,
            address(paymentToken)
        );
        vm.stopPrank();
    }

    // Fuzz tests for station capacity
    function testFuzz_RegisterStationCapacity(uint256 capacity) public {
        vm.assume(capacity > 0 && capacity <= 1000 * 10**18); // Reasonable bounds up to 1000 kW
        
        vm.startPrank(operator1);
        uint256 newStationId = chargingNetwork.registerStation(
            40000000,
            -74000000,
            capacity,
            20 * 10**16,
            IChargingNetwork.EnergySource.Grid,
            7 * 10**18,
            address(paymentToken)
        );
        vm.stopPrank();
        
        IChargingNetwork.Station memory station = chargingNetwork.getStation(newStationId);
        assertEq(station.capacity, capacity);
    }

    function testFuzz_Revert_RegisterStationZeroCapacity(uint256 capacity) public {
        vm.assume(capacity == 0);
        
        vm.startPrank(operator1);
        vm.expectRevert("Capacity must be positive");
        chargingNetwork.registerStation(
            40000000,
            -74000000,
            capacity,
            20 * 10**16,
            IChargingNetwork.EnergySource.Grid,
            7 * 10**18,
            address(paymentToken)
        );
        vm.stopPrank();
    }

    // Fuzz tests for max charging rate
    function testFuzz_RegisterStationMaxChargingRate(uint256 maxRate) public {
        vm.assume(maxRate > 0 && maxRate <= 350 * 10**18); // Reasonable bounds up to 350 kW
        
        vm.startPrank(operator1);
        uint256 newStationId = chargingNetwork.registerStation(
            40000000,
            -74000000,
            50 * 10**18,
            20 * 10**16,
            IChargingNetwork.EnergySource.Grid,
            maxRate,
            address(paymentToken)
        );
        vm.stopPrank();
        
        IChargingNetwork.Station memory station = chargingNetwork.getStation(newStationId);
        assertEq(station.maxChargingRate, maxRate);
    }

    function testFuzz_Revert_RegisterStationZeroMaxRate(uint256 maxRate) public {
        vm.assume(maxRate == 0);
        
        vm.startPrank(operator1);
        vm.expectRevert("Max charging rate must be positive");
        chargingNetwork.registerStation(
            40000000,
            -74000000,
            50 * 10**18,
            20 * 10**16,
            IChargingNetwork.EnergySource.Grid,
            maxRate,
            address(paymentToken)
        );
        vm.stopPrank();
    }

    // Fuzz tests for payment calculation
    function testFuzz_PaymentCalculation(uint256 energy, uint256 price) public {
        vm.assume(energy > 0 && energy <= 1000 * ENERGY_SCALE);
        vm.assume(price > 0 && price <= 1000 * PRICE_SCALE);
        
        // Register station with specific price
        vm.startPrank(operator1);
        uint256 newStationId = chargingNetwork.registerStation(
            41000000,
            -75000000,
            50 * 10**18,
            price,
            IChargingNetwork.EnergySource.Grid,
            7 * 10**18,
            address(paymentToken)
        );
        vm.stopPrank();
        
        // Complete charging session
        vm.startPrank(user1);
        uint256 sessionId = chargingNetwork.startSession(newStationId);
        chargingNetwork.recordEnergyConsumption(sessionId, energy);
        chargingNetwork.completeSession(sessionId);
        vm.stopPrank();
        
        // Verify cost calculation
        IChargingNetwork.Session memory session = chargingNetwork.getSession(sessionId);
        uint256 expectedCost = (energy * price) / ENERGY_SCALE;
        assertEq(session.totalCost, expectedCost);
    }

    // Fuzz tests for different energy sources
    function testFuzz_RegisterStationDifferentEnergySources(uint8 energySourceIndex) public {
        vm.assume(energySourceIndex < 4); // We have 4 energy sources
        
        IChargingNetwork.EnergySource energySource = IChargingNetwork.EnergySource(energySourceIndex);
        
        vm.startPrank(operator1);
        uint256 newStationId = chargingNetwork.registerStation(
            40000000,
            -74000000,
            50 * 10**18,
            20 * 10**16,
            energySource,
            7 * 10**18,
            address(paymentToken)
        );
        vm.stopPrank();
        
        IChargingNetwork.Station memory station = chargingNetwork.getStation(newStationId);
        assertEq(uint(station.energySource), energySourceIndex);
    }

    // Fuzz tests for operator balance withdrawal
    function testFuzz_WithdrawOperatorBalance(uint256 amount) public {
        // Setup: Create a paid session
        vm.startPrank(user1);
        uint256 sessionId = chargingNetwork.startSession(stationId1);
        chargingNetwork.recordEnergyConsumption(sessionId, 10 * ENERGY_SCALE);
        chargingNetwork.completeSession(sessionId);
        
        paymentToken.approve(address(chargingNetwork), 2 * 10**18);
        chargingNetwork.paySession(sessionId);
        vm.stopPrank();
        
        uint256 operatorBalance = chargingNetwork.getOperatorBalance(operator1);
        vm.assume(amount > 0 && amount <= operatorBalance);
        
        uint256 initialTokenBalance = paymentToken.balanceOf(operator1);
        
        vm.startPrank(operator1);
        chargingNetwork.withdrawOperatorBalance(operator1, amount);
        vm.stopPrank();
        
        assertEq(paymentToken.balanceOf(operator1), initialTokenBalance + amount);
        assertEq(chargingNetwork.getOperatorBalance(operator1), operatorBalance - amount);
    }

    function testFuzz_Revert_WithdrawOperatorBalanceExcess(uint256 amount) public {
        // Setup: Create a paid session
        vm.startPrank(user1);
        uint256 sessionId = chargingNetwork.startSession(stationId1);
        chargingNetwork.recordEnergyConsumption(sessionId, 10 * ENERGY_SCALE);
        chargingNetwork.completeSession(sessionId);
        
        paymentToken.approve(address(chargingNetwork), 2 * 10**18);
        chargingNetwork.paySession(sessionId);
        vm.stopPrank();
        
        uint256 operatorBalance = chargingNetwork.getOperatorBalance(operator1);
        vm.assume(amount > operatorBalance);
        
        vm.startPrank(operator1);
        vm.expectRevert("Insufficient balance");
        chargingNetwork.withdrawOperatorBalance(operator1, amount);
        vm.stopPrank();
    }

    // Fuzz tests for session state transitions
    function testFuzz_SessionStateTransitions(uint256 energy) public {
        vm.assume(energy > 0 && energy <= 100 * ENERGY_SCALE);
        
        vm.startPrank(user1);
        uint256 sessionId = chargingNetwork.startSession(stationId1);
        
        // Active state
        IChargingNetwork.Session memory session = chargingNetwork.getSession(sessionId);
        assertEq(uint(session.state), uint(IChargingNetwork.SessionState.Active));
        
        // Record energy (still active)
        chargingNetwork.recordEnergyConsumption(sessionId, energy);
        session = chargingNetwork.getSession(sessionId);
        assertEq(uint(session.state), uint(IChargingNetwork.SessionState.Active));
        
        // Complete session
        chargingNetwork.completeSession(sessionId);
        session = chargingNetwork.getSession(sessionId);
        assertEq(uint(session.state), uint(IChargingNetwork.SessionState.Completed));
        
        vm.stopPrank();
    }

    // Fuzz tests for boundary values
    function testFuzz_BoundaryEnergyValues(uint256 energy) public {
        vm.assume(energy == 1 || energy == ENERGY_SCALE || energy == 100 * ENERGY_SCALE);
        
        vm.startPrank(user1);
        uint256 sessionId = chargingNetwork.startSession(stationId1);
        chargingNetwork.recordEnergyConsumption(sessionId, energy);
        vm.stopPrank();
        
        IChargingNetwork.Session memory session = chargingNetwork.getSession(sessionId);
        assertEq(session.energyConsumed, energy);
    }

    function testFuzz_BoundaryPriceValues(uint256 price) public {
        vm.assume(price == 1 || price == PRICE_SCALE || price == 100 * PRICE_SCALE);
        
        vm.startPrank(operator1);
        chargingNetwork.updateStation(stationId1, price, true);
        vm.stopPrank();
        
        IChargingNetwork.Station memory station = chargingNetwork.getStation(stationId1);
        assertEq(station.pricePerKwh, price);
    }

    // Fuzz tests for multiple sessions
    function testFuzz_MultipleSessions(uint256 numSessions) public {
        vm.assume(numSessions > 0 && numSessions <= 10);
        
        // Register additional stations to support multiple concurrent sessions
        vm.startPrank(operator1);
        uint256[] memory stationIds = new uint256[](numSessions);
        for (uint256 i = 0; i < numSessions; i++) {
            stationIds[i] = chargingNetwork.registerStation(
                40000000 + int256(i * 100000),
                -74000000 - int256(i * 100000),
                50 * 10**18,
                20 * 10**16,
                IChargingNetwork.EnergySource.Grid,
                7 * 10**18,
                address(paymentToken)
            );
        }
        vm.stopPrank();
        
        vm.startPrank(user1);
        for (uint256 i = 0; i < numSessions; i++) {
            uint256 sessionId = chargingNetwork.startSession(stationIds[i]);
            chargingNetwork.recordEnergyConsumption(sessionId, 5 * ENERGY_SCALE);
            chargingNetwork.completeSession(sessionId);
        }
        vm.stopPrank();
        
        IChargingNetwork.Session[] memory userSessions = chargingNetwork.getUserSessions(user1);
        assertEq(userSessions.length, numSessions);
    }

    // Fuzz tests for edge case: very large energy consumption
    function testFuzz_LargeEnergyConsumption(uint256 energy) public {
        vm.assume(energy > 100 * ENERGY_SCALE && energy <= 10000 * ENERGY_SCALE);
        
        vm.startPrank(user1);
        uint256 sessionId = chargingNetwork.startSession(stationId1);
        chargingNetwork.recordEnergyConsumption(sessionId, energy);
        chargingNetwork.completeSession(sessionId);
        vm.stopPrank();
        
        IChargingNetwork.Session memory session = chargingNetwork.getSession(sessionId);
        assertEq(session.energyConsumed, energy);
        
        // Check that cost calculation doesn't overflow
        assertGt(session.totalCost, 0);
    }

    // Fuzz tests for repeated operations
    function testFuzz_RepeatedEnergyUpdates(uint256 numUpdates, uint256 energyPerUpdate) public {
        vm.assume(numUpdates > 0 && numUpdates <= 20);
        vm.assume(energyPerUpdate > 0 && energyPerUpdate <= 10 * ENERGY_SCALE);
        
        vm.startPrank(user1);
        uint256 sessionId = chargingNetwork.startSession(stationId1);
        
        for (uint256 i = 0; i < numUpdates; i++) {
            chargingNetwork.recordEnergyConsumption(sessionId, energyPerUpdate);
        }
        
        vm.stopPrank();
        
        IChargingNetwork.Session memory session = chargingNetwork.getSession(sessionId);
        assertEq(session.energyConsumed, numUpdates * energyPerUpdate);
    }
}