// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IChargingNetwork {
    // Enums
    enum SessionState {
        None,
        Active,
        Completed,
        Settled
    }

    enum EnergySource {
        Solar,
        Grid,
        CommunitySolar,
        BatteryStorage
    }

    // Structs
    struct Station {
        uint256 id;
        address operator;
        int256 latitude;
        int256 longitude;
        uint256 capacity; // in kW
        uint256 pricePerKwh; // in tokens (scaled by 1e18)
        EnergySource energySource;
        bool available;
        uint256 maxChargingRate; // in kW
        address paymentToken;
        bool active;
    }

    struct Session {
        uint256 id;
        uint256 stationId;
        address user;
        SessionState state;
        uint256 energyConsumed; // in kWh (scaled by 1e18)
        uint256 startTime;
        uint256 endTime;
        uint256 totalCost; // in tokens (scaled by 1e18)
        bool paid;
    }

    // Events
    event StationRegistered(
        uint256 indexed stationId,
        address indexed operator,
        int256 latitude,
        int256 longitude,
        EnergySource energySource
    );

    event StationUpdated(uint256 indexed stationId, uint256 pricePerKwh, bool available);

    event StationDeactivated(uint256 indexed stationId);

    event SessionStarted(uint256 indexed sessionId, uint256 indexed stationId, address indexed user);

    event EnergyConsumed(uint256 indexed sessionId, uint256 energyConsumed);

    event SessionCompleted(uint256 indexed sessionId, uint256 totalEnergy, uint256 totalCost);

    event SessionPaid(uint256 indexed sessionId, address indexed user, uint256 amount);

    event SessionSettled(uint256 indexed sessionId, address indexed operator, uint256 amount);

    event OperatorAuthorized(address indexed operator);
    event OperatorRevoked(address indexed operator);
    event StationOperatorAssigned(uint256 indexed stationId, address indexed operator);

    // Station Management
    function registerStation(
        int256 latitude,
        int256 longitude,
        uint256 capacity,
        uint256 pricePerKwh,
        EnergySource energySource,
        uint256 maxChargingRate,
        address paymentToken
    ) external returns (uint256);

    function updateStation(uint256 stationId, uint256 pricePerKwh, bool available) external;

    function deactivateStation(uint256 stationId) external;

    function getStation(uint256 stationId) external view returns (Station memory);

    function getAllStations() external view returns (Station[] memory);

    function getActiveStations() external view returns (Station[] memory);

    // Session Management
    function startSession(uint256 stationId) external returns (uint256);

    function recordEnergyConsumption(uint256 sessionId, uint256 energy) external;

    function completeSession(uint256 sessionId) external;

    function paySession(uint256 sessionId) external payable;

    function settleSession(uint256 sessionId) external;

    function getSession(uint256 sessionId) external view returns (Session memory);

    function getUserSessions(address user) external view returns (Session[] memory);

    function getStationSessions(uint256 stationId) external view returns (Session[] memory);

    // Accounting
    function getOperatorBalance(address operator) external view returns (uint256);

    function withdrawOperatorBalance(address operator, uint256 amount) external;

    // Validation
    function isValidStation(uint256 stationId) external view returns (bool);

    function isStationAvailable(uint256 stationId) external view returns (bool);
}
