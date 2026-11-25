// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/ChargingNetwork.sol";
import "../src/IChargingNetwork.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Ropa Energy Token", "RET") {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }
}

contract DeployScript is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy payment token
        MockERC20 paymentToken = new MockERC20();
        console.log("Payment Token deployed at:", address(paymentToken));

        // Deploy ChargingNetwork
        ChargingNetwork chargingNetwork = new ChargingNetwork(msg.sender);
        console.log("ChargingNetwork deployed at:", address(chargingNetwork));

        // Authorize the deployer as an operator
        chargingNetwork.authorizeOperator(msg.sender);

        // Register a sample station
        uint256 stationId = chargingNetwork.registerStation(
            51503300, // 51.503300 latitude (scaled by 1e6)
            -119500, // -0.119500 longitude (scaled by 1e6)
            50 * 1e18, // 50 kW capacity
            20 * 1e16, // 0.20 tokens per kWh
            IChargingNetwork.EnergySource.Solar,
            7 * 1e18, // 7 kW max charging rate
            address(paymentToken)
        );
        console.log("Sample station registered with ID:", stationId);

        vm.stopBroadcast();

        console.log("\n=== Deployment Summary ===");
        console.log("Payment Token:", address(paymentToken));
        console.log("ChargingNetwork:", address(chargingNetwork));
        console.log("Sample Station ID:", stationId);
    }
}
