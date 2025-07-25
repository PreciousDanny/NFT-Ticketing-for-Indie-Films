# 🎬 NFT Ticketing for Indie Films

> 🎟️ **Collectible film NFTs that double as event tickets and unlock exclusive behind-the-scenes content**

A revolutionary smart contract platform built on Stacks that enables indie filmmakers to sell NFT tickets for their film screenings while providing fans with collectible digital assets and exclusive access to behind-the-scenes content.

## ✨ Features

- 🎭 **Film Registration**: Creators can register their indie films with metadata
- 🎫 **NFT Ticket Minting**: Sell tickets as collectible NFTs with optional seat assignments
- 💰 **Revenue Sharing**: Automatic platform fee distribution and creator payouts
- 🎬 **Behind-the-Scenes Access**: Token holders unlock exclusive content
- 🔒 **Event Access Control**: Validate tickets for film screenings
- 📊 **Analytics Dashboard**: Track sales, revenue, and ticket usage
- 💎 **Special Editions**: Create limited special edition tickets
- 🎪 **Event Management**: Toggle film status and manage screenings

## 🚀 Quick Start

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd NFT-Ticketing-for-Indie-Films
```

2. Install dependencies:
```bash
npm install
```

3. Check contract compilation:
```bash
clarinet check
```

## 📖 Contract Overview

### Core Functions

#### 🎬 Film Management

**`create-film`** - Register a new indie film
```clarity
(create-film 
    "My Indie Film" 
    "A gripping story about..." 
    "https://poster-uri.com/poster.jpg"
    "https://trailer-uri.com/trailer.mp4"
    "https://behind-scenes.com/content.mp4"
    u1000000  ;; 1 STX ticket price
    u100      ;; max 100 tickets
    u1000000  ;; event date (block height)
    "Downtown Cinema Hall A"
)
```

**`toggle-film-status`** - Enable/disable ticket sales
```clarity
(toggle-film-status u1) ;; film-id
```

#### 🎫 Ticket Operations

**`mint-ticket`** - Purchase an NFT ticket
```clarity
(mint-ticket 
    u1                    ;; film-id
    'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7  ;; recipient
    (some "A12")         ;; optional seat number
    false                ;; special edition flag
)
```

**`use-ticket`** - Validate ticket for event entry
```clarity
(use-ticket u1) ;; token-id
```

**`transfer`** - Transfer ticket to another user
```clarity
(transfer u1 tx-sender 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

#### 📊 Read-Only Functions

**`get-film`** - Get film details
```clarity
(get-film u1) ;; film-id
```

**`get-ticket`** - Get ticket information
```clarity
(get-ticket u1) ;; token-id
```

**`get-user-tickets`** - List user's tickets
```clarity
(get-user-tickets 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

**`get-behind-scenes-access`** - Check content access
```clarity
(get-behind-scenes-access 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 u1)
```

**`get-film-stats`** - Get film statistics
```clarity
(get-film-stats u1)
```

**`is-ticket-valid`** - Validate ticket status
```clarity
(is-ticket-valid u1)
```

## 💼 Business Model

### Revenue Sharing
- **Platform Fee**: 2.5% (configurable by contract owner)
- **Creator Revenue**: 97.5% goes directly to filmmaker
- **Automatic Distribution**: Payments split during ticket purchase

### Use Cases

1. **🎭 Indie Film Screenings**: Sell tickets for film premieres and screenings
2. **🎪 Film Festivals**: Create collectible tickets for festival events
3. **🎬 Virtual Screenings**: Access online premieres with NFT tickets
4. **📱 Digital Collectibles**: Fans collect memorable film experiences
5. **🎁 Exclusive Content**: Behind-the-scenes access for ticket holders
6. **💎 Limited Editions**: Special collector tickets with unique artwork

## 🛠️ Development

### Testing

Run the test suite:
```bash
npm test
```

Or using Clarinet:
```bash
clarinet test
```

### Deployment

Deploy to testnet:
```bash
clarinet integrate
```

Deploy to mainnet:
```bash
clarinet deploy --network mainnet
```

## 📋 Error Codes

| Code | Description |
|------|-------------|
| u100 | Owner only operation |
| u101 | Not token owner |
| u102 | Film not found |
| u103 | Ticket not found |
| u104 | Ticket already used |
| u105 | Event not active |
| u106 | Insufficient payment |
| u107 | Transfer failed |
| u108 | Minting disabled |
| u109 | Invalid recipient |
| u110 | No revenue to withdraw |

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Film Creator  │───▶│  Smart Contract │◀───│   Ticket Buyer  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │  NFT Collection │
                    │  (Film Tickets) │
                    └─────────────────┘
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🌟 Support

If you find this project helpful, please consider:
- ⭐ Starring the repository
- 🐛 Reporting bugs
- 💡 Suggesting new features
- 📖 Improving documentation

---

**Built with ❤️ for the indie film community on Stacks blockchain**
