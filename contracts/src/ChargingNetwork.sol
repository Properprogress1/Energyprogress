// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./IChargingNetwork.sol";

contract ChargingNetwork is IChargingNetwork, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // State variables
    uint256 private nextStationId;
    uint256 private nextSessionId;
    
    mapping(uint256 => Station) public stations;
    mapping(uint256 => Session) public sessions;
    mapping(address => uint256[]) public userSessions;
    mapping(uint256 => uint256[]) public stationSessions;
    mapping(address => uint256) public operatorBalances;
    
    mapping(uint256 => address) public stationOperators;
    mapping(address => bool) public authorizedOperators;
    
    uint256 public constant LATITUDE_SCALE = 1e6;
    uint256 public constant LONGITUDE_SCALE = 1e6;
    uint256 public constant ENERGY_SCALE = 1e18;
    uint256 public constant PRICE_SCALE = 1e18;
    
    // Modifiers
    modifier onlyStationOperator(uint256 stationId) {
        require(
            stationOperators[stationId] == msg.sender,
            "Not station operator"
        );
        _;
    }

    modifier onlyAuthorizedOperator() {
        require(authorizedOperators[msg.sender], "Not authorized operator");
        _;
    }

    modifier sessionExists(uint256 sessionId) {
        require(sessions[sessionId].id != 0, "Session does not exist");
        _;
    }

    modifier sessionState(uint256 sessionId, SessionState expectedState) {
        require(
            sessions[sessionId].state == expectedState,
            "Invalid session state"
        );
        _;
    }

    modifier onlySessionUser(uint256 sessionId) {
        require(
            sessions[sessionId].user == msg.sender,
            "Not session user"
        );
        _;
    }

    // Constructor
    constructor(address initialOwner) Ownable(initialOwner) {
        nextStationId = 1;
        nextSessionId = 1;
    }

    // Operator Management
    function authorizeOperator(address operator) external onlyOwner {
        authorizedOperators[operator] = true;
        emit OperatorAuthorized(operator);
    }

    function revokeOperator(address operator) external onlyOwner {
        authorizedOperators[operator] = false;
        emit OperatorRevoked(operator);
    }

    // Station Management
    function registerStation(
        int256 latitude,
        int256 longitude,
        uint256 capacity,
        uint256 pricePerKwh,
        EnergySource energySource,
        uint256 maxChargingRate,
        address paymentToken
    ) external onlyAuthorizedOperator returns (uint256) {
        require(capacity > 0, "Capacity must be positive");
        require(pricePerKwh > 0, "Price must be positive");
        require(maxChargingRate > 0, "Max charging rate must be positive");
        require(paymentToken != address(0), "Invalid payment token");
        
        // Validate coordinates (simplified - production would use proper geospatial validation)
        // casting to 'int256' is safe because LATITUDE_SCALE and LONGITUDE_SCALE are constants (1e6)
        // and the multiplication won't overflow given the ranges being checked
        require(
            latitude >= -90 * int256(LATITUDE_SCALE) && 
            latitude <= 90 * int256(LATITUDE_SCALE),
            "Invalid latitude"
        );
        require(
            longitude >= -180 * int256(LONGITUDE_SCALE) && 
            longitude < 180 * int256(LONGITUDE_SCALE),
            "Invalid longitude"
        );

        uint256 stationId = nextStationId++;
        
        stations[stationId] = Station({
            id: stationId,
            operator: msg.sender,
            latitude: latitude,
            longitude: longitude,
            capacity: capacity,
            pricePerKwh: pricePerKwh,
            energySource: energySource,
            available: true,
            maxChargingRate: maxChargingRate,
            paymentToken: paymentToken,
            active: true
        });

        stationOperators[stationId] = msg.sender;

        emit StationOperatorAssigned(stationId, msg.sender);

        emit StationRegistered(
            stationId,
            msg.sender,
            latitude,
            longitude,
            energySource
        );

        return stationId;
    }

    function updateStation(
        uint256 stationId,
        uint256 pricePerKwh,
        bool available
    ) external onlyStationOperator(stationId) {
        require(stations[stationId].active, "Station not active");
        require(pricePerKwh > 0, "Price must be positive");

        stations[stationId].pricePerKwh = pricePerKwh;
        stations[stationId].available = available;

        emit StationUpdated(stationId, pricePerKwh, available);
    }

    function deactivateStation(uint256 stationId) external onlyStationOperator(stationId) {
        require(stations[stationId].active, "Station already inactive");
        
        stations[stationId].active = false;
        stations[stationId].available = false;

        emit StationDeactivated(stationId);
    }

    function getStation(uint256 stationId) external view override returns (Station memory) {
        require(stations[stationId].id != 0, "Station does not exist");
        return stations[stationId];
    }

    function getAllStations() external view override returns (Station[] memory) {
        uint256 activeCount = 0;
        for (uint256 i = 1; i < nextStationId; i++) {
            if (stations[i].id != 0) {
                activeCount++;
            }
        }

        Station[] memory allStations = new Station[](activeCount);
        uint256 index = 0;
        for (uint256 i = 1; i < nextStationId; i++) {
            if (stations[i].id != 0) {
                allStations[index] = stations[i];
                index++;
            }
        }

        return allStations;
    }

    function getActiveStations() external view override returns (Station[] memory) {
        uint256 activeCount = 0;
        for (uint256 i = 1; i < nextStationId; i++) {
            if (stations[i].id != 0 && stations[i].active && stations[i].available) {
                activeCount++;
            }
        }

        Station[] memory activeStations = new Station[](activeCount);
        uint256 index = 0;
        for (uint256 i = 1; i < nextStationId; i++) {
            if (stations[i].id != 0 && stations[i].active && stations[i].available) {
                activeStations[index] = stations[i];
                index++;
            }
        }

        return activeStations;
    }

    // Session Management
    function startSession(uint256 stationId) external returns (uint256) {
        require(isValidStation(stationId), "Invalid station");
        require(isStationAvailable(stationId), "Station not available");
        
        // Check if station already has an active session (single-session capacity)
        uint256[] storage stationSessionIds = stationSessions[stationId];
        bool stationInUse = false;
        for (uint256 i = 0; i < stationSessionIds.length; i++) {
            if (sessions[stationSessionIds[i]].state == SessionState.Active) {
                stationInUse = true;
                break;
            }
        }
        require(!stationInUse, "Station already in use");

        uint256 sessionId = nextSessionId++;

        sessions[sessionId] = Session({
            id: sessionId,
            stationId: stationId,
            user: msg.sender,
            state: SessionState.Active,
            energyConsumed: 0,
            startTime: block.timestamp,
            endTime: 0,
            totalCost: 0,
            paid: false
        });

        userSessions[msg.sender].push(sessionId);
        stationSessions[stationId].push(sessionId);

        emit SessionStarted(sessionId, stationId, msg.sender);

        return sessionId;
    }

    function recordEnergyConsumption(uint256 sessionId, uint256 energy) 
        external 
        sessionExists(sessionId)
        sessionState(sessionId, SessionState.Active)
        onlySessionUser(sessionId)
    {
        require(energy > 0, "Energy must be positive");
        
        sessions[sessionId].energyConsumed += energy;

        emit EnergyConsumed(sessionId, sessions[sessionId].energyConsumed);
    }

    function completeSession(uint256 sessionId) 
        external 
        sessionExists(sessionId)
        sessionState(sessionId, SessionState.Active)
        onlySessionUser(sessionId)
    {
        Session storage session = sessions[sessionId];
        
        session.state = SessionState.Completed;
        session.endTime = block.timestamp;
        
        // Calculate total cost
        Station memory station = stations[session.stationId];
        session.totalCost = (session.energyConsumed * station.pricePerKwh) / ENERGY_SCALE;

        emit SessionCompleted(sessionId, session.energyConsumed, session.totalCost);
    }

    function paySession(uint256 sessionId) 
        external 
        payable 
        nonReentrant
        sessionExists(sessionId)
        sessionState(sessionId, SessionState.Completed)
        onlySessionUser(sessionId)
    {
        Session storage session = sessions[sessionId];
        require(!session.paid, "Session already paid");
        
        Station memory station = stations[session.stationId];
        IERC20 paymentToken = IERC20(station.paymentToken);

        emit SessionPaid(sessionId, msg.sender, session.totalCost);

        require(msg.value == 0, "Use station payment token");
        paymentToken.safeTransferFrom(msg.sender, address(this), session.totalCost);

        session.paid = true;
        
        // Credit operator balance
        operatorBalances[station.operator] += session.totalCost;
    }

    function settleSession(uint256 sessionId) 
        external 
        sessionExists(sessionId)
        sessionState(sessionId, SessionState.Completed)
    {
        Session storage session = sessions[sessionId];
        require(session.paid, "Session not paid");
        require(session.state != SessionState.Settled, "Session already settled");

        session.state = SessionState.Settled;

        emit SessionSettled(sessionId, stations[session.stationId].operator, session.totalCost);
    }

    function getSession(uint256 sessionId) external view override returns (Session memory) {
        require(sessions[sessionId].id != 0, "Session does not exist");
        return sessions[sessionId];
    }

    function getUserSessions(address user) external view override returns (Session[] memory) {
        uint256[] memory sessionIds = userSessions[user];
        Session[] memory userSessionData = new Session[](sessionIds.length);
        
        for (uint256 i = 0; i < sessionIds.length; i++) {
            userSessionData[i] = sessions[sessionIds[i]];
        }

        return userSessionData;
    }

    function getStationSessions(uint256 stationId) external view override returns (Session[] memory) {
        uint256[] memory sessionIds = stationSessions[stationId];
        Session[] memory stationSessionData = new Session[](sessionIds.length);
        
        for (uint256 i = 0; i < sessionIds.length; i++) {
            stationSessionData[i] = sessions[sessionIds[i]];
        }

        return stationSessionData;
    }

    // Accounting
    function getOperatorBalance(address operator) external view override returns (uint256) {
        return operatorBalances[operator];
    }

    function withdrawOperatorBalance(address operator, uint256 amount) 
        external 
        nonReentrant
    {
        require(msg.sender == operator || msg.sender == owner(), "Unauthorized");
        require(operatorBalances[operator] >= amount, "Insufficient balance");
        
        operatorBalances[operator] -= amount;
        
        address paymentToken = address(0);
        
        // Find operator's payment token (simplified - assumes all stations use same token)
        for (uint256 i = 1; i < nextStationId; i++) {
            if (stations[i].operator == operator && stations[i].id != 0) {
                paymentToken = stations[i].paymentToken;
                break;
            }
        }
        
        require(paymentToken != address(0), "No payment token found");
        
        IERC20(paymentToken).safeTransfer(operator, amount);
    }

    // Validation
    function isValidStation(uint256 stationId) public view override returns (bool) {
        return stations[stationId].id != 0 && stations[stationId].active;
    }

    function isStationAvailable(uint256 stationId) public view override returns (bool) {
        return stations[stationId].id != 0 && 
               stations[stationId].active && 
               stations[stationId].available;
    }
}