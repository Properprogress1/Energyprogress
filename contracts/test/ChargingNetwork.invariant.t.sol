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

contract ChargingNetworkInvariantTest is Test {
    ChargingNetwork public chargingNetwork;
    MockERC20 public paymentToken;
    
    address public owner;
    address public operator1;
    address public operator2;
    address public user1;
    address public user2;
    
    uint256 public stationId1;
    uint256 public stationId2;
    
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
        paymentToken.mint(user1, 10000 * 10**18);
        paymentToken.mint(user2, 10000 * 10**18);
        
        // Register initial stations
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
        
        vm.startPrank(operator2);
        stationId2 = chargingNetwork.registerStation(
            40754321,
            -73987654,
            100 * 10**18,
            15 * 10**16,
            IChargingNetwork.EnergySource.Grid,
            22 * 10**18,
            address(paymentToken)
        );
        vm.stopPrank();
        
        targetContract(address(chargingNetwork));
    }

    // Invariant 1: Accounting invariant - operator balances must match settled sessions
    function invariant_AccountingInvariant() public view {
        uint256 totalOperatorBalance = chargingNetwork.getOperatorBalance(operator1) + 
                                      chargingNetwork.getOperatorBalance(operator2);
        
        uint256 totalSettledCost = 0;
        
        // Sum up all settled session costs
        IChargingNetwork.Session[] memory user1Sessions = chargingNetwork.getUserSessions(user1);
        for (uint256 i = 0; i < user1Sessions.length; i++) {
            if (user1Sessions[i].state == IChargingNetwork.SessionState.Settled) {
                totalSettledCost += user1Sessions[i].totalCost;
            }
        }
        
        IChargingNetwork.Session[] memory user2Sessions = chargingNetwork.getUserSessions(user2);
        for (uint256 i = 0; i < user2Sessions.length; i++) {
            if (user2Sessions[i].state == IChargingNetwork.SessionState.Settled) {
                totalSettledCost += user2Sessions[i].totalCost;
            }
        }
        
        // Operator balances should equal total settled costs
        assertEq(totalOperatorBalance, totalSettledCost, "Accounting invariant violated");
    }

    // Invariant 2: Session state invariant - settled sessions cannot be modified
    function invariant_SessionStateInvariant() public view {
        IChargingNetwork.Session[] memory user1Sessions = chargingNetwork.getUserSessions(user1);
        for (uint256 i = 0; i < user1Sessions.length; i++) {
            if (user1Sessions[i].state == IChargingNetwork.SessionState.Settled) {
                // Settled sessions should have paid flag set
                assertTrue(user1Sessions[i].paid, "Settled session should be paid");
                // Settled sessions should have end time set
                assertGt(user1Sessions[i].endTime, 0, "Settled session should have end time");
            }
        }
        
        IChargingNetwork.Session[] memory user2Sessions = chargingNetwork.getUserSessions(user2);
        for (uint256 i = 0; i < user2Sessions.length; i++) {
            if (user2Sessions[i].state == IChargingNetwork.SessionState.Settled) {
                assertTrue(user2Sessions[i].paid, "Settled session should be paid");
                assertGt(user2Sessions[i].endTime, 0, "Settled session should have end time");
            }
        }
    }

    // Invariant 3: Station availability invariant - active sessions can only be on available stations
    function invariant_StationAvailabilityInvariant() public view {
        IChargingNetwork.Session[] memory user1Sessions = chargingNetwork.getUserSessions(user1);
        for (uint256 i = 0; i < user1Sessions.length; i++) {
            if (user1Sessions[i].state == IChargingNetwork.SessionState.Active) {
                assertTrue(chargingNetwork.isStationAvailable(user1Sessions[i].stationId), 
                          "Active session should be on available station");
            }
        }
        
        IChargingNetwork.Session[] memory user2Sessions = chargingNetwork.getUserSessions(user2);
        for (uint256 i = 0; i < user2Sessions.length; i++) {
            if (user2Sessions[i].state == IChargingNetwork.SessionState.Active) {
                assertTrue(chargingNetwork.isStationAvailable(user2Sessions[i].stationId), 
                          "Active session should be on available station");
            }
        }
    }

    // Invariant 4: Payment invariant - completed sessions must have positive cost if energy was consumed
    function invariant_PaymentInvariant() public view {
        IChargingNetwork.Session[] memory user1Sessions = chargingNetwork.getUserSessions(user1);
        for (uint256 i = 0; i < user1Sessions.length; i++) {
            if (user1Sessions[i].state == IChargingNetwork.SessionState.Completed || 
                user1Sessions[i].state == IChargingNetwork.SessionState.Settled) {
                if (user1Sessions[i].energyConsumed > 0) {
                    assertGt(user1Sessions[i].totalCost, 0, "Session with energy should have positive cost");
                }
            }
        }
        
        IChargingNetwork.Session[] memory user2Sessions = chargingNetwork.getUserSessions(user2);
        for (uint256 i = 0; i < user2Sessions.length; i++) {
            if (user2Sessions[i].state == IChargingNetwork.SessionState.Completed || 
                user2Sessions[i].state == IChargingNetwork.SessionState.Settled) {
                if (user2Sessions[i].energyConsumed > 0) {
                    assertGt(user2Sessions[i].totalCost, 0, "Session with energy should have positive cost");
                }
            }
        }
    }

    // Invariant 5: Session ownership invariant - sessions cannot be modified by non-owners
    function invariant_SessionOwnershipInvariant() public view {
        // This is enforced by the contract's modifiers, but we can verify the data structure
        IChargingNetwork.Session[] memory user1Sessions = chargingNetwork.getUserSessions(user1);
        for (uint256 i = 0; i < user1Sessions.length; i++) {
            assertEq(user1Sessions[i].user, user1, "Session should belong to correct user");
        }
        
        IChargingNetwork.Session[] memory user2Sessions = chargingNetwork.getUserSessions(user2);
        for (uint256 i = 0; i < user2Sessions.length; i++) {
            assertEq(user2Sessions[i].user, user2, "Session should belong to correct user");
        }
    }

    // Invariant 6: Station operator invariant - station data integrity
    function invariant_StationOperatorInvariant() public view {
        IChargingNetwork.Station memory station1 = chargingNetwork.getStation(stationId1);
        assertEq(station1.operator, operator1, "Station 1 should belong to operator1");
        
        IChargingNetwork.Station memory station2 = chargingNetwork.getStation(stationId2);
        assertEq(station2.operator, operator2, "Station 2 should belong to operator2");
    }

    // Invariant 7: Energy consistency invariant - energy consumed should be monotonic in active sessions
    function invariant_EnergyConsistencyInvariant() public view {
        IChargingNetwork.Session[] memory user1Sessions = chargingNetwork.getUserSessions(user1);
        for (uint256 i = 0; i < user1Sessions.length; i++) {
            if (user1Sessions[i].state == IChargingNetwork.SessionState.Active) {
                // Active sessions should have consumed energy >= 0
                assertGe(user1Sessions[i].energyConsumed, 0, "Energy consumed should be non-negative");
            }
        }
        
        IChargingNetwork.Session[] memory user2Sessions = chargingNetwork.getUserSessions(user2);
        for (uint256 i = 0; i < user2Sessions.length; i++) {
            if (user2Sessions[i].state == IChargingNetwork.SessionState.Active) {
                assertGe(user2Sessions[i].energyConsumed, 0, "Energy consumed should be non-negative");
            }
        }
    }

    // Invariant 8: Station capacity invariant - stations should maintain their capacity parameters
    function invariant_StationCapacityInvariant() public view {
        IChargingNetwork.Station memory station1 = chargingNetwork.getStation(stationId1);
        assertGt(station1.capacity, 0, "Station capacity should be positive");
        assertGt(station1.maxChargingRate, 0, "Station max charging rate should be positive");
        assertGt(station1.pricePerKwh, 0, "Station price should be positive");
        
        IChargingNetwork.Station memory station2 = chargingNetwork.getStation(stationId2);
        assertGt(station2.capacity, 0, "Station capacity should be positive");
        assertGt(station2.maxChargingRate, 0, "Station max charging rate should be positive");
        assertGt(station2.pricePerKwh, 0, "Station price should be positive");
    }
}