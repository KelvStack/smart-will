# 🛡️ Smart-Will - Blockchain-Based Digital Estate Planning Platform

> **Secure your digital legacy with blockchain technology**

A comprehensive **blockchain-powered digital estate planning platform** built on the Stacks blockchain that enables users to create immutable, self-executing wills with advanced security features and multi-signature governance.

[![Stacks](https://img.shields.io/badge/Built%20on-Stacks-orange?style=for-the-badge&logo=stacks)](https://stacks.co)
[![Clarity](https://img.shields.io/badge/Smart%20Contract-Clarity-blue?style=for-the-badge)](https://clarity-lang.org)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

## 🌟 Overview

SmartWill revolutionizes estate planning by combining blockchain security, smart contract automation, and advanced governance mechanisms. Whether you're a crypto investor, high-net-worth individual, or anyone seeking secure digital inheritance, SmartWill provides enterprise-grade security with user-friendly functionality.

### ✨ Key Benefits

- **🔒 Immutable Security**: Blockchain-secured wills that cannot be tampered with
- **⚡ Automated Execution**: Smart contracts automatically distribute assets to beneficiaries
- **👥 Multi-Signature Governance**: Guardian-based social recovery system
- **⏰ Time Lock Protection**: Configurable delays to prevent unauthorized access
- **💓 Liveness Monitoring**: Heartbeat system ensures timely execution
- **🚨 Emergency Protocols**: Guardian-approved emergency execution workflows

## 🚀 Features

### 📝 Digital Will Management

- **Smart Will Creation**: Create immutable wills with metadata support
- **Dynamic Beneficiary Management**: Add/remove beneficiaries with precise percentage allocations
- **Asset Deposit System**: Secure STX deposits with balance tracking
- **Will Status Control**: Activate/deactivate wills as needed

### 🛡️ Advanced Security Features

- **Time Lock System**: Configurable lock periods (minimum 30 days)
- **Guardian Network**: Up to 5 guardians per will with majority approval
- **Heartbeat Monitoring**: Automatic liveness detection with configurable timeouts
- **Emergency Execution**: Guardian-approved emergency asset distribution

### 👥 Beneficiary System

- **Flexible Allocation**: Percentage-based distribution (0.01% precision)
- **Multiple Beneficiaries**: Support for up to 10 beneficiaries per will
- **Dynamic Updates**: Modify beneficiary allocations anytime
- **Validation System**: Ensures total allocation equals 100%

### 🔐 Guardian System

- **Social Recovery**: Guardian-based account recovery
- **Multi-Signature Approval**: Majority approval for emergency actions
- **Guardian Management**: Add/remove guardians with proper authorization
- **Emergency Protocols**: Structured emergency execution workflow

## 🏗️ Smart Contract Architecture

### Core Components

#### 📊 Data Structures

```clarity
;; Main will storage with comprehensive metadata
(define-map wills uint {
  creator: principal,
  is-active: bool,
  created-at: uint,
  last-updated: uint,
  total-stx-amount: uint,
  beneficiary-count: uint,
  is-executed: bool,
  execution-block: (optional uint),
  metadata-uri: (optional (string-ascii 256))
})

;; Beneficiary management with percentage allocations
(define-map beneficiaries {will-id: uint, beneficiary-address: principal} {
  percentage: uint, ;; 0-10000 (0-100.00%)
  is-active: bool,
  added-at: uint,
  notes: (optional (string-ascii 256))
})
```

#### 🔧 Key Constants

```clarity
(define-constant MAX_BENEFICIARIES u10)      ;; Maximum beneficiaries per will
(define-constant MAX_GUARDIANS u5)           ;; Maximum guardians per will
(define-constant MIN_TIME_LOCK u4320)        ;; Minimum lock period (30 days)
(define-constant HEARTBEAT_TIMEOUT u25920)   ;; Default heartbeat timeout (180 days)
```

### 🎯 Core Functions

#### Will Management

- `create-will`: Create a new digital will with metadata
- `update-will-metadata`: Update will information
- `toggle-will-status`: Activate/deactivate wills
- `deposit-stx`: Add STX assets to the will

#### Beneficiary Management

- `add-beneficiary`: Add beneficiaries with percentage allocation
- `remove-beneficiary`: Remove beneficiaries from wills
- `update-beneficiary-percentage`: Modify allocation percentages
- `distribute-assets`: Execute asset distribution to beneficiaries

#### Security Features

- `enable-time-lock`: Set up time-delayed execution
- `add-guardian`: Add guardians for social recovery
- `enable-heartbeat`: Set up liveness monitoring
- `request-emergency-execution`: Initiate emergency procedures

#### Query Functions

- `get-will-details`: Retrieve complete will information
- `get-beneficiary-details`: Get beneficiary allocation data
- `get-will-summary`: Comprehensive will status overview
- `is-will-ready-for-execution`: Check execution readiness

## 🛠️ Technical Specifications

### Smart Contract Details

- **Language**: Clarity (Stacks blockchain)
- **Contract Size**: 1,100+ lines of code
- **Gas Optimization**: Efficient data structures and function calls
- **Error Handling**: Comprehensive error codes and validation

### Security Features

- **Access Control**: Multi-layer authorization checks
- **Input Validation**: Comprehensive parameter validation
- **State Management**: Immutable blockchain state
- **Emergency Controls**: Guardian-based override mechanisms

### Precision & Limits

| Feature              | Limit        | Notes                         |
| -------------------- | ------------ | ----------------------------- |
| Beneficiaries        | 10 per will  | Prevents complexity overhead  |
| Guardians            | 5 per will   | Optimal for majority approval |
| Percentage Precision | 0.01%        | 10,000 basis points system    |
| Time Lock Minimum    | 30 days      | 4,320 blocks on Stacks        |
| Heartbeat Timeout    | Configurable | Default 180 days              |

## 🚀 Getting Started

### Prerequisites

- **Stacks CLI**: Latest version for deployment
- **Clarinet**: For local development and testing
- **Node.js**: 18+ for frontend integration
- **Stacks Wallet**: For transaction signing

### Installation

1. **Clone the repository**

```bash
git clone https://github.com/TheSoftNode/blockchain-based-smart-will.git
cd blockchain-based-smart-will
```

2. **Install dependencies**

```bash
cd smart-will
npm install
```

3. **Set up Clarinet**

```bash
clarinet check
clarinet test
```

4. **Deploy to testnet**

```bash
clarinet deploy --testnet
```

### 📁 Project Structure

```
smart-will/
├── contracts/
│   └── smart-will.clar          # Main smart contract
├── tests/
│   └── smart-will.test.ts       # Comprehensive test suite
├── settings/
│   ├── Devnet.toml             # Development configuration
│   ├── Testnet.toml            # Testnet configuration
│   └── Mainnet.toml            # Mainnet configuration
├── Clarinet.toml               # Project configuration
└── package.json                # Dependencies
```

## 🧪 Testing

### Run Test Suite

```bash
# Run all tests
clarinet test

# Run specific test file
clarinet test tests/smart-will.test.ts

# Check contract syntax
clarinet check
```

### Test Coverage

- ✅ Will creation and management
- ✅ Beneficiary operations
- ✅ Asset deposit and distribution
- ✅ Time lock functionality
- ✅ Guardian system
- ✅ Emergency execution
- ✅ Error handling and edge cases

## 📖 Usage Examples

### Creating a Will

```clarity
;; Create a new will with metadata
(contract-call? .smart-will create-will
  (some "ipfs://QmExample..."))
```

### Adding Beneficiaries

```clarity
;; Add a beneficiary with 50% allocation
(contract-call? .smart-will add-beneficiary
  u1                                    ;; will-id
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7  ;; beneficiary address
  u5000                                 ;; 50.00% allocation
  (some "Primary beneficiary - spouse"))
```

### Setting Up Security

```clarity
;; Enable time lock (90 days)
(contract-call? .smart-will enable-time-lock u1 u12960)

;; Add guardian
(contract-call? .smart-will add-guardian
  u1
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7
  (some "Trusted family member"))

;; Enable heartbeat (180 days timeout)
(contract-call? .smart-will enable-heartbeat u1 u25920)
```

## 🔒 Security Model

### Multi-Layer Protection

1. **Blockchain Security**: Immutable storage on Stacks blockchain
2. **Access Control**: Function-level authorization checks
3. **Time Locks**: Configurable delays for sensitive operations
4. **Guardian System**: Multi-signature social recovery
5. **Heartbeat Monitoring**: Automatic liveness detection

### Attack Vectors & Mitigations

| Attack Vector       | Mitigation                  |
| ------------------- | --------------------------- |
| Unauthorized Access | Multi-layer authorization   |
| Front-running       | Time locks and delays       |
| Social Engineering  | Guardian consensus required |
| Key Loss            | Social recovery system      |
| Premature Execution | Heartbeat and time locks    |

## 🎯 Use Cases

### Individual Users

- **Crypto Investors**: Secure inheritance of digital assets
- **High-Net-Worth Individuals**: Comprehensive estate planning
- **Tech Professionals**: Blockchain-native inheritance solutions

### Organizations

- **Family Offices**: Multi-generational wealth transfer
- **DAOs**: Decentralized governance succession
- **Businesses**: Key management and succession planning

## 🛣️ Roadmap

### Phase 1: Core Platform ✅

- [x] Smart contract development
- [x] Basic will creation and management
- [x] Beneficiary system
- [x] Asset distribution

### Phase 2: Advanced Security ✅

- [x] Time lock system
- [x] Guardian network
- [x] Emergency execution
- [x] Heartbeat monitoring

### Phase 3: Enhanced Features (Future)

- [ ] Multi-asset support (BTC, NFTs)
- [ ] AI-powered advisory system
- [ ] Mobile application
- [ ] Institutional features

### Phase 4: Ecosystem Integration (Future)

- [ ] DeFi protocol integration
- [ ] Cross-chain compatibility
- [ ] Legal framework compliance
- [ ] Enterprise partnerships

## 📊 Economics

### Contract Fees

- **Will Creation**: 1 STX (configurable)
- **Asset Storage**: No additional fees
- **Distribution**: Gas costs only
- **Guardian Operations**: Gas costs only

### Cost Benefits

- **Traditional Estate Planning**: $1,000-$5,000+ per will
- **SmartWill**: ~$5-$10 in gas fees + 1 STX creation fee
- **Ongoing Maintenance**: Minimal gas costs for updates

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Setup

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

### Code Standards

- Follow Clarity best practices
- Add comprehensive comments
- Include error handling
- Write accompanying tests
- Update documentation

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Stacks Foundation**: For the robust blockchain infrastructure
- **Clarity Language**: For secure smart contract development
- **Open Source Community**: For tools and inspiration
- **Early Adopters**: For feedback and testing

## 📞 Support & Community

- **Documentation**: [Coming Soon]
- **Discord**: [Community Server - Coming Soon]
- **GitHub Issues**: [Bug Reports & Feature Requests](https://github.com/TheSoftNode/blockchain-based-smart-will/issues)
- **Email**: [Support Contact - Coming Soon]

## ⚠️ Disclaimer

SmartWill is experimental software. While we've implemented comprehensive security measures, users should:

- Understand the risks of blockchain technology
- Test thoroughly on testnet before mainnet use
- Consider legal implications in their jurisdiction
- Keep backup access methods for critical assets
- Consult with legal professionals for complex estates

---

**SmartWill** - Securing your digital legacy for future generations. 🛡️✨

_Built with ❤️ on the Stacks blockchain_
