# Ropa Citi

<div align="center">

**Urban Energy Intelligence for Sustainable Cities**

Ropa Citi aims to help UK local authorities and infrastructure partners decide where to invest in urban energy infrastructure and track how it operates. EV charging is the first use case.

[![Solidity](https://img.shields.io/badge/Solidity-0.8.20-blue)](https://soliditylang.org/)
[![Next.js](https://img.shields.io/badge/Next.js-16.3-black)](https://nextjs.org/)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.0-blue)](https://www.typescript.org/)
[![Foundry](https://img.shields.io/badge/Foundry-1.8.3-orange)](https://getfoundry.sh/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

</div>

## Vision

Ropa Citi connects three decisions in the life of an energy project.

- **Plan.** Combine charger coverage with local demand and accessibility evidence to compare potential sites.
- **Invest.** Compare a site's expected use, installation costs, and operating costs before committing funding.
- **Operate.** Track energy delivered and explore how payments and operator balances can be recorded transparently.

The current prototype maps simulated EV chargers across six UK cities, lets users test proposed sites against sample coverage points, and demonstrates charging and token settlement. The planning estimates use sample data. The longer-term vision includes renewables, community energy, and battery storage.

## Product priorities

1. **Verified charger inventory.** Import charger locations, connector types, power ratings and data timestamps. Use this inventory as the baseline for site comparisons.
2. **Local demand and accessibility.** Add inputs such as EV uptake, access to off-street parking and travel distance. Show the evidence and assumptions behind each estimate.
3. **Investment scenarios.** Compare expected utilisation and costs, and export a shortlist with the supporting evidence for council review.
4. **Operational reporting.** Connect charger usage and payment records so operators can report how a deployed site performs.

## 🏗️ Architecture

### System Overview

Ropa Citi is a monorepo containing:

```
ropa-citi/
├── apps/
│   └── web/                 # Next.js frontend with interactive map
├── contracts/               # Solidity smart contracts
│   ├── src/                # Contract source files
│   ├── test/               # Foundry test suites
│   ├── script/             # Deployment scripts
│   └── foundry.toml         # Foundry configuration
├── docs/                    # Architecture and security documentation
├── packages/               # Shared packages (future)
└── README.md               # This file
```

### Technology Stack

#### Blockchain Layer
- **Solidity 0.8.20**: Smart contract language
- **Foundry 1.8.3**: Ethereum development toolkit
- **OpenZeppelin Contracts**: Security-tested contract libraries
- **Anvil**: Local Ethereum development environment

#### Frontend Layer
- **Next.js 16.3**: React framework with app router
- **TypeScript 5.0**: Type-safe JavaScript
- **Tailwind CSS 4**: Utility-first CSS framework
- **Leaflet**: Open-source map library
- **OpenStreetMap**: Free map tiles
- **wagmi 3.7**: React hooks for Ethereum
- **viem**: TypeScript interface for Ethereum

#### Testing
- **Foundry**: Comprehensive testing framework
- **Unit Tests**: 44 tests covering all contract functions
- **Fuzz Tests**: 22 tests for edge case coverage
- **Invariant Tests**: 8 protocol invariants verified across 256 sequences

## 🔋 Smart Contract Design

### Core Contracts

#### IChargingNetwork.sol
Defines the public interface for the charging network:
- Station management functions
- Session lifecycle operations
- Payment and settlement mechanisms
- Query functions for stations and sessions

#### ChargingNetwork.sol
Main implementation contract with:
- **Access Control**: Owner and operator role management
- **Station Registry**: Register, update, deactivate charging stations
- **Session Management**: State machine (None → Active → Completed → Settled)
- **Payment Processing**: Token-based energy payments
- **Settlement System**: Operator balance management

### Key Design Patterns

#### State Machine
Sessions follow a strict state machine:
```
None → Active → Completed → Settled
```
No state regression is possible, ensuring session integrity.

#### Access Control
- **Owner Level**: Contract deployment, operator authorization
- **Operator Level**: Station management, balance withdrawal
- **User Level**: Session operations, payments

#### Scaling Factors
- **Energy**: 1e18 (1 kWh = 1e18 units)
- **Price**: 1e18 (1 token = 1e18 units)
- **Coordinates**: 1e6 (latitude/longitude precision)

## 🗺️ Geospatial Architecture

### Map Implementation
- **Interactive Map**: Leaflet with OpenStreetMap tiles
- **Station Markers**: Color-coded by energy source
- **Sample station data**: Simulated availability, pricing, and energy sources
- **Urban Planning Intelligence**: Coverage analysis and recommendations

### UK city map
The map opens in London and lets you switch to Birmingham, Manchester, Cardiff, Edinburgh, or Belfast. Each city has:
- **5 Simulated Charging Stations**: Sample locations, availability, and prices in GBP
- **Multiple Energy Sources**: Solar, Grid, Community Solar, Battery Storage
- **Local Planning Estimates**: Coverage calculated around the selected city centre
- **Coverage Analysis**: Accessibility scoring and gap identification

### On-Chain vs Off-Chain Data

#### On-Chain State
- Station registration and ownership
- Session creation and state transitions
- Payment transactions and settlement
- Operator balance accounting

#### Off-Chain/Simulated State
- Energy consumption telemetry (oracle boundary)
- Map tiles and geospatial data
- Station metadata and historical analytics
- Urban planning calculations

**Important**: The system explicitly models energy consumption as simulated input. In production, this would be replaced by trusted oracle data from physical charging hardware.

## 🔒 Security Analysis

### Security Features
- **Access Control**: Role-based permissions with modifiers
- **Reentrancy Protection**: OpenZeppelin ReentrancyGuard
- **Safe Token Transfers**: SafeERC20 library
- **State Machine Enforcement**: Strict transition validation
- **Deterministic Calculations**: No oracle dependencies for pricing

### Threat Model
- **Unauthorized Access**: Prevented by access control modifiers
- **Payment Manipulation**: Mitigated by deterministic calculations
- **Session Hijacking**: Protected by ownership checks
- **Reentrancy**: Prevented by guards and proper patterns
- **Oracle Manipulation**: Acknowledged as production concern

### Security Assumptions
- Payment tokens are standard-compliant ERC20
- Underlying blockchain network security
- Users secure their private keys
- Trusted oracle integration for production

For detailed security analysis, see [docs/security-analysis.md](docs/security-analysis.md)

## 🧪 Testing Strategy

### Test Coverage
- **44 Unit Tests**: All contract functions with positive and negative cases
- **22 Fuzz Tests**: Edge cases for energy, pricing, coordinates, payments
- **8 Invariant Tests**: Protocol invariants verified across 256 random sequences

### Running Tests
```bash
# Run all tests
cd contracts
forge test

# Run specific test suites
forge test --match-test testFuzz    # Fuzz tests only
forge test --match-test invariant   # Invariant tests only

# Run with gas snapshots
forge test --gas-report
```

### Test Results
- **Unit Tests**: 44/44 passed
- **Fuzz Tests**: 22/22 passed (256 runs each)
- **Invariant Tests**: 8/8 passed (256 runs, 128k calls)

## 🚀 Getting Started

### Prerequisites
- Node.js 20+
- Foundry (installed via foundryup)
- Git

### Installation

1. **Clone the repository**
```bash
git clone <repository-url>
cd "Ropa Energy"
```

2. **Install Foundry**
```bash
curl -L https://foundry.paradigm.xyz | bash
export PATH="$PATH:$HOME/.foundry/bin"
```

3. **Install dependencies**
```bash
# Install contract dependencies
cd contracts
forge install OpenZeppelin/openzeppelin-contracts

# Install frontend dependencies
cd ../apps/web
npm install
```

### Local Development

#### Smart Contracts
```bash
cd contracts

# Build contracts
forge build

# Run tests
forge test

# Start local blockchain
anvil

# Deploy contracts
forge script script/Deploy.s.sol:DeployScript --rpc-url http://localhost:8545 --broadcast --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --unlocked
```

#### Frontend
```bash
cd apps/web

# Start development server
npm run dev -- --webpack

# Access at http://localhost:3000
```

### Demo Scenario

1. **Start Anvil** (local blockchain)
```bash
cd contracts
anvil
```

2. **Deploy Contracts** (in another terminal)
```bash
cd contracts
forge script script/Deploy.s.sol:DeployScript --rpc-url http://localhost:8545 --broadcast --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --unlocked
```

3. **Start Frontend** (in another terminal)
```bash
cd apps/web
npm run dev -- --webpack
```

4. **Try the map simulation**
- Open http://localhost:3000 and choose a UK city, then select a station.
- Start a simulated session, add energy, and complete the session.
- Simulate payment and click **Finish session** to reset.

5. **Try the local blockchain demo**
- Open **Local blockchain demo** and connect the funded Anvil test account on chain 31337.
- Start a session at the deployed sample station, record 5 simulated kWh, complete the session, pay in RET, and settle.
- See the [demo guide](docs/demo-scenario.md) for setup and expected results.

## 📊 Urban Planning Intelligence

The system provides urban planning analysis including:

### Metrics
- **Charging Accessibility Score**: Overall infrastructure quality (0-100%)
- **Average Station Distance**: Mean distance between stations
- **Renewable Energy Percentage**: Clean energy source distribution
- **Infrastructure Density**: Stations per square kilometer
- **Demand Coverage**: Estimated demand satisfaction

### Features
- **Coverage Gap Analysis**: Identifies areas with insufficient charging access
- **Energy Source Distribution**: Visual breakdown of energy types
- **Optimal Station Range**: Recommended spacing (0.5-2.0 km)
- **Recommendations**: Actionable suggestions for infrastructure improvement

## 🏢 Smart Contract Functions

### Station Management
- `registerStation()`: Register new charging station
- `updateStation()`: Update station pricing and availability
- `deactivateStation()`: Remove station from active service
- `getStation()`: Query station details
- `getAllStations()`: Get all registered stations
- `getActiveStations()`: Get available stations only

### Session Management
- `startSession()`: Begin new charging session
- `recordEnergyConsumption()`: Update energy usage
- `completeSession()`: End active session
- `paySession()`: Process payment for completed session
- `settleSession()`: Finalize transaction
- `getSession()`: Query session details
- `getUserSessions()`: Get user's session history
- `getStationSessions()`: Get station's session history

### Accounting
- `getOperatorBalance()`: Query operator earnings
- `withdrawOperatorBalance()`: Withdraw operator funds

## 🔮 Future Improvements

### Smart Contract Enhancements
- [ ] Multi-sig owner controls
- [ ] Emergency pause functionality
- [ ] Session timeout mechanisms
- [ ] Rate limiting for operations
- [ ] Trusted oracle integration
- [ ] Payment token whitelisting
- [ ] Upgrade patterns (UUPS/Transparent)

### Frontend Enhancements
- [ ] Real blockchain integration (currently simulated)
- [ ] Transaction history display
- [ ] Enhanced map features (heatmaps, coverage zones)
- [ ] Mobile optimization
- [ ] Advanced analytics dashboard
- [ ] Multi-language support

### Infrastructure
- [ ] Mainnet deployment
- [ ] Distributed oracle network
- [ ] Monitoring and alerting
- [ ] Bug bounty program
- [ ] Third-party security audit

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions are welcome! Please read our contribution guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines
- Follow existing code style and conventions
- Add tests for new features
- Update documentation as needed
- Ensure all tests pass before submitting

## 📧 Contact

For questions or feedback about Ropa Citi, please open an issue on GitHub.

## 🙏 Acknowledgments

- **Foundry**: Ethereum development toolkit
- **OpenZeppelin**: Security-tested smart contract libraries
- **Leaflet**: Open-source mapping library
- **OpenStreetMap**: Free map data and tiles
- **Next.js**: React framework
- **wagmi**: React hooks for Ethereum

## 📚 Resources

- [Foundry Documentation](https://book.getfoundry.sh/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts)
- [Solidity Documentation](https://docs.soliditylang.org/)
- [Leaflet Documentation](https://leafletjs.com/)
- [wagmi Documentation](https://wagmi.sh/)

---

**Built with ❤️ for sustainable urban mobility**