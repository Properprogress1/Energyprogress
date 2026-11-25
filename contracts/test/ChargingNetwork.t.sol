// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ChargingNetwork.sol";
import "../src/IChargingNetwork.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract ChargingNetworkTest is Test {
    ChargingNetwork public chargingNetwork;
    MockERC20 public paymentToken;

    address public owner;
    address public operator1;
    address public operator2;
    address public user1;
    address public user2;

    uint256 public stationId1;
    uint256 public stationId2;
    uint256 public sessionId;

    // Constants
    uint256 constant LATITUDE_SCALE = 1e6;
    uint256 constant LONGITUDE_SCALE = 1e6;
    uint256 constant ENERGY_SCALE = 1e18;
    uint256 constant PRICE_SCALE = 1e18;

    function setUp() public {
        owner = address(this);
        operator1 = address(0x1);
        operator2 = address(0x2);
        user1 = address(0x3);
        user2 = address(0x4);

        paymentToken = new MockERC20();
        chargingNetwork = new ChargingNetwork(owner);

        // Authorize operators
        chargingNetwork.authorizeOperator(operator1);
        chargingNetwork.authorizeOperator(operator2);

        // Fund users with tokens
        paymentToken.mint(user1, 1000 * 10 ** 18);
        paymentToken.mint(user2, 1000 * 10 ** 18);

        // Register stations
        vm.startPrank(operator1);
        stationId1 = chargingNetwork.registerStation(
            40712345, // 40.712345
            -74004567, // -74.004567
            50 * 10 ** 18, // 50 kW capacity
            20 * 10 ** 16, // 0.20 tokens per kWh
            IChargingNetwork.EnergySource.Solar,
            7 * 10 ** 18, // 7 kW max charging rate
            address(paymentToken)
        );
        vm.stopPrank();

        vm.startPrank(operator2);
        stationId2 = chargingNetwork.registerStation(
            40754321, // 40.754321
            -73987654, // -73.987654
            100 * 10 ** 18, // 100 kW capacity
            15 * 10 ** 16, // 0.15 tokens per kWh
            IChargingNetwork.EnergySource.Grid,
            22 * 10 ** 18, // 22 kW max charging rate
            address(paymentToken)
        );
        vm.stopPrank();
    }

    // Station Registration Tests
    function test_RegisterStation() public {
        vm.startPrank(operator1);
        uint256 newStationId = chargingNetwork.registerStation(
            35000000, // 35.0
            -80000000, // -80.0
            75 * 10 ** 18,
            25 * 10 ** 16,
            IChargingNetwork.EnergySource.CommunitySolar,
            11 * 10 ** 18,
            address(paymentToken)
        );
        vm.stopPrank();

        IChargingNetwork.Station memory station = chargingNetwork.getStation(newStationId);
        assertEq(station.id, newStationId);
        assertEq(station.operator, operator1);
        assertEq(station.latitude, 35000000);
        assertEq(station.longitude, -80000000);
        assertEq(station.capacity, 75 * 10 ** 18);
        assertEq(station.pricePerKwh, 25 * 10 ** 16);
        assertEq(uint256(station.energySource), uint256(IChargingNetwork.EnergySource.CommunitySolar));
        assertTrue(station.available);
        assertEq(station.maxChargingRate, 11 * 10 ** 18);
        assertEq(station.paymentToken, address(paymentToken));
        assertTrue(station.active);
    }

    function test_Revert_RegisterStation_Unauthorized() public {
        vm.expectRevert("Not authorized operator");
        chargingNetwork.registerStation(
            40000000,
            -74000000,
            50 * 10 ** 18,
            20 * 10 ** 16,
            IChargingNetwork.EnergySource.Solar,
            7 * 10 ** 18,
            address(paymentToken)
        );
    }

    function test_Revert_RegisterStation_InvalidCapacity() public {
        vm.startPrank(operator1);
        vm.expectRevert("Capacity must be positive");
        chargingNetwork.registerStation(
            40000000,
            -74000000,
            0,
            20 * 10 ** 16,
            IChargingNetwork.EnergySource.Solar,
            7 * 10 ** 18,
            address(paymentToken)
        );
        vm.stopPrank();
    }

    function test_Revert_RegisterStation_InvalidPrice() public {
        vm.startPrank(operator1);
        vm.expectRevert("Price must be positive");
        chargingNetwork.registerStation(
            40000000,
            -74000000,
            50 * 10 ** 18,
            0,
            IChargingNetwork.EnergySource.Solar,
            7 * 10 ** 18,
            address(paymentToken)
        );
        vm.stopPrank();
    }

    function test_Revert_RegisterStation_InvalidLatitude() public {
        vm.startPrank(operator1);
        vm.expectRevert("Invalid latitude");
        chargingNetwork.registerStation(
            91000000, // 91.0 (invalid)
            -74000000,
            50 * 10 ** 18,
            20 * 10 ** 16,
            IChargingNetwork.EnergySource.Solar,
            7 * 10 ** 18,
            address(paymentToken)
        );
        vm.stopPrank();
    }

    function test_Revert_RegisterStation_InvalidLongitude() public {
        vm.startPrank(operator1);
        vm.expectRevert("Invalid longitude");
        chargingNetwork.registerStation(
            40000000,
            180000001, // 180.000001 (invalid)
            50 * 10 ** 18,
            20 * 10 ** 16,
            IChargingNetwork.EnergySource.Solar,
            7 * 10 ** 18,
            address(paymentToken)
        );
        vm.stopPrank();
    }

    // Station Update Tests
    function test_UpdateStation() public {
        vm.startPrank(operator1);
        chargingNetwork.updateStation(stationId1, 30 * 10 ** 16, false);
        vm.stopPrank();

        IChargingNetwork.Station memory station = chargingNetwork.getStation(stationId1);
        assertEq(station.pricePerKwh, 30 * 10 ** 16);
        assertFalse(station.available);
    }

    function test_Revert_UpdateStation_Unauthorized() public {
        vm.expectRevert("Not station operator");
        chargingNetwork.updateStation(stationId1, 30 * 10 ** 16, false);
    }

    function test_Revert_UpdateStation_InactiveStation() public {
        vm.startPrank(operator1);
        chargingNetwork.deactivateStation(stationId1);
        vm.expectRevert("Station not active");
        chargingNetwork.updateStation(stationId1, 30 * 10 ** 16, true);
        vm.stopPrank();
    }

    // Station Deactivation Tests
    function test_DeactivateStation() public {
        vm.startPrank(operator1);
        chargingNetwork.deactivateStation(stationId1);
        vm.stopPrank();

        IChargingNetwork.Station memory station = chargingNetwork.getStation(stationId1);
        assertFalse(station.active);
        assertFalse(station.available);
    }

    function test_Revert_DeactivateStation_Unauthorized() public {
        vm.expectRevert("Not station operator");
        chargingNetwork.deactivateStation(stationId1);
    }

    function test_Revert_DeactivateStation_AlreadyInactive() public {
        vm.startPrank(operator1);
        chargingNetwork.deactivateStation(stationId1);
        vm.expectRevert("Station already inactive");
        chargingNetwork.deactivateStation(stationId1);
        vm.stopPrank();
    }

    // Session Management Tests
    function test_StartSession() public {
        vm.startPrank(user1);
        sessionId = chargingNetwork.startSession(stationId1);
        vm.stopPrank();

        IChargingNetwork.Session memory session = chargingNetwork.getSession(sessionId);
        assertEq(session.id, sessionId);
        assertEq(session.stationId, stationId1);
        assertEq(session.user, user1);
        assertEq(uint256(session.state), uint256(IChargingNetwork.SessionState.Active));
        assertEq(session.energyConsumed, 0);
        assertGt(session.startTime, 0);
        assertEq(session.endTime, 0);
        assertEq(session.totalCost, 0);
        assertFalse(session.paid);
    }

    function test_Revert_StartSession_InvalidStation() public {
        vm.startPrank(user1);
        vm.expectRevert("Invalid station");
        chargingNetwork.startSession(999);
        vm.stopPrank();
    }

    function test_Revert_StartSession_StationNotAvailable() public {
        vm.startPrank(operator1);
        chargingNetwork.updateStation(stationId1, 20 * 10 ** 16, false);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert("Station not available");
        chargingNetwork.startSession(stationId1);
        vm.stopPrank();
    }

    function test_Revert_StartSession_StationInUse() public {
        vm.startPrank(user1);
        chargingNetwork.startSession(stationId1);
        vm.stopPrank();

        vm.startPrank(user2);
        vm.expectRevert("Station already in use");
        chargingNetwork.startSession(stationId1);
        vm.stopPrank();
    }

    // Energy Consumption Tests
    function test_RecordEnergyConsumption() public {
        vm.startPrank(user1);
        sessionId = chargingNetwork.startSession(stationId1);
        chargingNetwork.recordEnergyConsumption(sessionId, 5 * ENERGY_SCALE);
        vm.stopPrank();

        IChargingNetwork.Session memory session = chargingNetwork.getSession(sessionId);
        assertEq(session.energyConsumed, 5 * ENERGY_SCALE);
    }

    function test_RecordEnergyConsumption_Multiple() public {
        vm.startPrank(user1);
        sessionId = chargingNetwork.startSession(stationId1);
        chargingNetwork.recordEnergyConsumption(sessionId, 3 * ENERGY_SCALE);
        chargingNetwork.recordEnergyConsumption(sessionId, 2 * ENERGY_SCALE);
        vm.stopPrank();

        IChargingNetwork.Session memory session = chargingNetwork.getSession(sessionId);
        assertEq(session.energyConsumed, 5 * ENERGY_SCALE);
    }

    function test_Revert_RecordEnergyConsumption_Unauthorized() public {
        vm.startPrank(user1);
        sessionId = chargingNetwork.startSession(stationId1);
        vm.stopPrank();

        vm.startPrank(user2);
        vm.expectRevert("Not session user");
        chargingNetwork.recordEnergyConsumption(sessionId, 5 * ENERGY_SCALE);
        vm.stopPrank();
    }

    function test_Revert_RecordEnergyConsumption_InvalidState() public {
        vm.startPrank(user1);
        sessionId = chargingNetwork.startSession(stationId1);
        chargingNetwork.completeSession(sessionId);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert("Invalid session state");
        chargingNetwork.recordEnergyConsumption(sessionId, 5 * ENERGY_SCALE);
        vm.stopPrank();
    }

    function test_Revert_RecordEnergyConsumption_ZeroEnergy() public {
        vm.startPrank(user1);
        sessionId = chargingNetwork.startSession(stationId1);
        vm.expectRevert("Energy must be positive");
        chargingNetwork.recordEnergyConsumption(sessionId, 0);
        vm.stopPrank();
    }

    // Session Completion Tests
    function test_CompleteSession() public {
        vm.startPrank(user1);
        sessionId = chargingNetwork.startSession(stationId1);
        chargingNetwork.recordEnergyConsumption(sessionId, 10 * ENERGY_SCALE);
        chargingNetwork.completeSession(sessionId);
        vm.stopPrank();

        IChargingNetwork.Session memory session = chargingNetwork.getSession(sessionId);
        assertEq(uint256(session.state), uint256(IChargingNetwork.SessionState.Completed));
        assertGt(session.endTime, 0);
        assertEq(session.totalCost, 2 * 10 ** 18); // 10 kWh * 0.20 tokens/kWh = 2 tokens
    }

    function test_Revert_CompleteSession_Unauthorized() public {
        vm.startPrank(user1);
        sessionId = chargingNetwork.startSession(stationId1);
        vm.stopPrank();

        vm.startPrank(user2);
        vm.expectRevert("Not session user");
        chargingNetwork.completeSession(sessionId);
        vm.stopPrank();
    }

    function test_Revert_CompleteSession_InvalidState() public {
        vm.startPrank(user1);
        sessionId = chargingNetwork.startSession(stationId1);
        chargingNetwork.completeSession(sessionId);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert("Invalid session state");
        chargingNetwork.completeSession(sessionId);
        vm.stopPrank();
    }

    // Payment Tests
    function test_PaySession() public {
        vm.startPrank(user1);
        sessionId = chargingNetwork.startSession(stationId1);
        chargingNetwork.recordEnergyConsumption(sessionId, 10 * ENERGY_SCALE);
        chargingNetwork.completeSession(sessionId);

        paymentToken.approve(address(chargingNetwork), 2 * 10 ** 18);
        chargingNetwork.paySession(sessionId);
        vm.stopPrank();

        IChargingNetwork.Session memory session = chargingNetwork.getSession(sessionId);
        assertTrue(session.paid);

        uint256 operatorBalance = chargingNetwork.getOperatorBalance(operator1);
        assertEq(operatorBalance, 2 * 10 ** 18);
    }

    function test_Revert_PaySession_WithEther() public {
        vm.deal(user1, 2 ether);
        vm.startPrank(user1);
        sessionId = chargingNetwork.startSession(stationId1);
        chargingNetwork.recordEnergyConsumption(sessionId, 10 * ENERGY_SCALE);
        chargingNetwork.completeSession(sessionId);
        paymentToken.approve(address(chargingNetwork), 2 ether);

        vm.expectRevert("Use station payment token");
        chargingNetwork.paySession{value: 2 ether}(sessionId);
        vm.stopPrank();

        assertFalse(chargingNetwork.getSession(sessionId).paid);
        assertEq(chargingNetwork.getOperatorBalance(operator1), 0);
    }

    function test_Revert_PaySession_AlreadyPaid() public {
        vm.startPrank(user1);
        sessionId = chargingNetwork.startSession(stationId1);
        chargingNetwork.recordEnergyConsumption(sessionId, 10 * ENERGY_SCALE);
        chargingNetwork.completeSession(sessionId);

        paymentToken.approve(address(chargingNetwork), 2 * 10 ** 18);
        chargingNetwork.paySession(sessionId);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert("Session already paid");
        chargingNetwork.paySession(sessionId);
        vm.stopPrank();
    }

    function test_Revert_PaySession_InsufficientPayment() public {
        vm.startPrank(user1);
        sessionId = chargingNetwork.startSession(stationId1);
        chargingNetwork.recordEnergyConsumption(sessionId, 10 * ENERGY_SCALE);
        chargingNetwork.completeSession(sessionId);
        vm.stopPrank();

        vm.startPrank(user1);
        paymentToken.approve(address(chargingNetwork), 1 * 10 ** 18); // Only 1 token, need 2
        vm.expectRevert();
        chargingNetwork.paySession(sessionId);
        vm.stopPrank();
    }

    // Settlement Tests
    function test_SettleSession() public {
        vm.startPrank(user1);
        sessionId = chargingNetwork.startSession(stationId1);
        chargingNetwork.recordEnergyConsumption(sessionId, 10 * ENERGY_SCALE);
        chargingNetwork.completeSession(sessionId);

        paymentToken.approve(address(chargingNetwork), 2 * 10 ** 18);
        chargingNetwork.paySession(sessionId);
        vm.stopPrank();

        chargingNetwork.settleSession(sessionId);

        IChargingNetwork.Session memory session = chargingNetwork.getSession(sessionId);
        assertEq(uint256(session.state), uint256(IChargingNetwork.SessionState.Settled));
    }

    function test_Revert_SettleSession_NotPaid() public {
        vm.startPrank(user1);
        sessionId = chargingNetwork.startSession(stationId1);
        chargingNetwork.recordEnergyConsumption(sessionId, 10 * ENERGY_SCALE);
        chargingNetwork.completeSession(sessionId);
        vm.stopPrank();

        vm.expectRevert("Session not paid");
        chargingNetwork.settleSession(sessionId);
    }

    function test_Revert_SettleSession_AlreadySettled() public {
        vm.startPrank(user1);
        sessionId = chargingNetwork.startSession(stationId1);
        chargingNetwork.recordEnergyConsumption(sessionId, 10 * ENERGY_SCALE);
        chargingNetwork.completeSession(sessionId);

        paymentToken.approve(address(chargingNetwork), 2 * 10 ** 18);
        chargingNetwork.paySession(sessionId);
        vm.stopPrank();

        chargingNetwork.settleSession(sessionId);

        vm.expectRevert("Invalid session state");
        chargingNetwork.settleSession(sessionId);
    }

    // Access Control Tests
    function test_AuthorizeOperator() public {
        address newOperator = address(0x5);
        chargingNetwork.authorizeOperator(newOperator);

        vm.startPrank(newOperator);
        uint256 newStationId = chargingNetwork.registerStation(
            40000000,
            -74000000,
            50 * 10 ** 18,
            20 * 10 ** 16,
            IChargingNetwork.EnergySource.Solar,
            7 * 10 ** 18,
            address(paymentToken)
        );
        vm.stopPrank();

        assertEq(newStationId, 3); // Third station
    }

    function test_RevokeOperator() public {
        chargingNetwork.revokeOperator(operator1);

        vm.startPrank(operator1);
        vm.expectRevert("Not authorized operator");
        chargingNetwork.registerStation(
            40000000,
            -74000000,
            50 * 10 ** 18,
            20 * 10 ** 16,
            IChargingNetwork.EnergySource.Solar,
            7 * 10 ** 18,
            address(paymentToken)
        );
        vm.stopPrank();
    }

    function test_Revert_AuthorizeOperator_Unauthorized() public {
        vm.startPrank(user1);
        vm.expectRevert();
        chargingNetwork.authorizeOperator(operator1);
        vm.stopPrank();
    }

    // Accounting Tests
    function test_WithdrawOperatorBalance() public {
        vm.startPrank(user1);
        sessionId = chargingNetwork.startSession(stationId1);
        chargingNetwork.recordEnergyConsumption(sessionId, 10 * ENERGY_SCALE);
        chargingNetwork.completeSession(sessionId);

        paymentToken.approve(address(chargingNetwork), 2 * 10 ** 18);
        chargingNetwork.paySession(sessionId);
        vm.stopPrank();

        uint256 initialBalance = paymentToken.balanceOf(operator1);

        vm.startPrank(operator1);
        chargingNetwork.withdrawOperatorBalance(operator1, 2 * 10 ** 18);
        vm.stopPrank();

        assertEq(paymentToken.balanceOf(operator1), initialBalance + 2 * 10 ** 18);
        assertEq(chargingNetwork.getOperatorBalance(operator1), 0);
    }

    function test_Revert_WithdrawOperatorBalance_Unauthorized() public {
        vm.startPrank(user1);
        vm.expectRevert("Unauthorized");
        chargingNetwork.withdrawOperatorBalance(operator1, 1 * 10 ** 18);
        vm.stopPrank();
    }

    function test_Revert_WithdrawOperatorBalance_InsufficientBalance() public {
        vm.startPrank(operator1);
        vm.expectRevert("Insufficient balance");
        chargingNetwork.withdrawOperatorBalance(operator1, 1 * 10 ** 18);
        vm.stopPrank();
    }

    // Query Tests
    function test_GetAllStations() public view {
        IChargingNetwork.Station[] memory allStations = chargingNetwork.getAllStations();
        assertEq(allStations.length, 2);
        assertEq(allStations[0].id, stationId1);
        assertEq(allStations[1].id, stationId2);
    }

    function test_GetActiveStations() public {
        vm.startPrank(operator1);
        chargingNetwork.updateStation(stationId1, 20 * 10 ** 16, false);
        vm.stopPrank();

        IChargingNetwork.Station[] memory activeStations = chargingNetwork.getActiveStations();
        assertEq(activeStations.length, 1);
        assertEq(activeStations[0].id, stationId2);
    }

    function test_GetUserSessions() public {
        vm.startPrank(user1);
        sessionId = chargingNetwork.startSession(stationId1);
        vm.stopPrank();

        IChargingNetwork.Session[] memory userSessions = chargingNetwork.getUserSessions(user1);
        assertEq(userSessions.length, 1);
        assertEq(userSessions[0].id, sessionId);
    }

    function test_GetStationSessions() public {
        vm.startPrank(user1);
        sessionId = chargingNetwork.startSession(stationId1);
        vm.stopPrank();

        IChargingNetwork.Session[] memory stationSessions = chargingNetwork.getStationSessions(stationId1);
        assertEq(stationSessions.length, 1);
        assertEq(stationSessions[0].id, sessionId);
    }

    // Validation Tests
    function test_IsValidStation() public view {
        assertTrue(chargingNetwork.isValidStation(stationId1));
        assertFalse(chargingNetwork.isValidStation(999));
    }

    function test_IsStationAvailable() public {
        assertTrue(chargingNetwork.isStationAvailable(stationId1));

        vm.startPrank(operator1);
        chargingNetwork.updateStation(stationId1, 20 * 10 ** 16, false);
        vm.stopPrank();

        assertFalse(chargingNetwork.isStationAvailable(stationId1));
    }

    // Complete Flow Test
    function test_CompleteChargingFlow() public {
        // User starts session
        vm.startPrank(user1);
        sessionId = chargingNetwork.startSession(stationId1);

        // User consumes energy
        chargingNetwork.recordEnergyConsumption(sessionId, 20 * ENERGY_SCALE);

        // User completes session
        chargingNetwork.completeSession(sessionId);

        // User pays
        uint256 expectedCost = 4 * 10 ** 18; // 20 kWh * 0.20 tokens/kWh
        paymentToken.approve(address(chargingNetwork), expectedCost);
        chargingNetwork.paySession(sessionId);
        vm.stopPrank();

        // Verify session state
        IChargingNetwork.Session memory session = chargingNetwork.getSession(sessionId);
        assertEq(uint256(session.state), uint256(IChargingNetwork.SessionState.Completed));
        assertEq(session.energyConsumed, 20 * ENERGY_SCALE);
        assertEq(session.totalCost, expectedCost);
        assertTrue(session.paid);

        // Verify operator balance
        assertEq(chargingNetwork.getOperatorBalance(operator1), expectedCost);

        // System settles session
        chargingNetwork.settleSession(sessionId);

        // Verify final state
        session = chargingNetwork.getSession(sessionId);
        assertEq(uint256(session.state), uint256(IChargingNetwork.SessionState.Settled));
    }
}
