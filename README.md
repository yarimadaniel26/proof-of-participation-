# 🎯 Proof of Participation Smart Contract

A Clarity smart contract for logging and tracking participation in events on the Stacks blockchain. Perfect for hackathons, workshops, conferences, and community events! 🚀

## ✨ Features

- 📝 **Event Creation**: Create time-bound events with descriptions
- 🎫 **Participation Tracking**: Log unique participation per address
- 🏆 **Leaderboards**: Track participation order and rankings  
- 📊 **Statistics**: View user stats and contract-wide metrics
- 🔒 **Owner Controls**: Activate/deactivate events as needed
- ⏰ **Time-based Logic**: Events have start and end blocks

## 🛠️ Core Functions

### 📅 Event Management

#### `create-event`
```clarity
(create-event "Event Name" "Description" start-block end-block)
```
Creates a new event (owner only). Returns event ID.

#### `deactivate-event` / `reactivate-event`
```clarity
(deactivate-event event-id)
(reactivate-event event-id)
```
Toggle event active status (owner only).

### 🎪 Participation

#### `participate`
```clarity
(participate event-id "participation-data")
```
Register participation in an active event. Each address can only participate once per event.

### 🔍 Read Functions

#### `get-event`
```clarity
(get-event event-id)
```
Returns complete event information.

#### `has-participated`
```clarity
(has-participated event-id participant-address)
```
Check if an address has participated in an event.

#### `get-participation-proof`
```clarity
(get-participation-proof event-id participant-address)
```
Get participation details including block height and data.

#### `get-user-stats`
```clarity
(get-user-stats participant-address)
```
Returns user's total event count and last participation.

#### `get-contract-stats`
```clarity
(get-contract-stats)
```
View overall contract statistics.

## 🚀 Quick Start

### Deploy with Clarinet

```bash
clarinet new proof-of-participation
cd proof-of-participation
```

Copy the contract code to `contracts/proof-of-participation.clar`

### Test Deployment

```bash
clarinet console
```

```clarity
;; Create an event (as contract owner)
(contract-call? .proof-of-participation create-event "Test Event" "A test event" u1000 u2000)

;; Participate in event
(contract-call? .proof-of-participation participate u1 "Hello World")

;; Check participation
(contract-call? .proof-of-participation has-participated u1 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

## 📋 Error Codes

| Code | Error | Description |
|------|-------|-------------|
| u100 | `err-owner-only` | Function restricted to contract owner |
| u101 | `err-event-not-found` | Event ID doesn't exist |
| u102 | `err-event-not-active` | Event is not currently active |
| u103 | `err-already-participated` | Address already participated |
| u104 | `err-event-already-exists` | Event ID collision |
| u105 | `err-invalid-end-block` | End block before start block |
| u106 | `err-invalid-start-block` | Start block in the past |
| u107 | `err-event-ended` | Event has already ended |

## 🎯 Use Cases

- 🎓 **Educational Events**: Track workshop attendance
- 🏆 **Competitions**: Log hackathon participation  
- 🎪 **Community Events**: Record meetup attendance
- 🎫 **Conferences**: Digital participation certificates
- 🎮 **Gaming**: Achievement and quest completion
- 📚 **Learning**: Course completion tracking

## 🔧 Data Structures

### Events Map
```clarity
{
  name: string-ascii 50,
  description: string-ascii 200,
  start-block: uint,
  end-block: uint,
  is-active: bool,
  total-participants: uint,
  created-at: uint,
  creator: principal
}
```

### Participants Map
```clarity
{
  participated-at: uint,
  participation-data: string-ascii 100,
  block-height: uint
}
```

## 🤝 Contributing

Feel free to submit issues and enhancement requests! This is an MVP designed for learning and can be extended with additional features.

## 📄 License

MIT License - feel free to use in your projects! 🎉
```

## Git Commit Message

```
feat: implement proof-of-participation MVP with event logging and uniqueness tracking
```

## GitHub Pull Request Title

```
🎯 Add Proof of Participation Smart Contract MVP
```

## GitHub Pull Request Description

```markdown
## 🎯 Proof of Participation Smart Contract MVP

This PR adds a complete Clarity smart contract for tracking event participation on Stacks blockchain.

### ✨ What's Added

- **Smart Contract** (`contracts/proof-of-participation.clar`)
  - Event creation and management system
  - Unique participation tracking per address
  - Time-based event logic with start/end blocks
  - Leaderboard and ranking system
  - Comprehensive statistics tracking
  - Owner-only administrative controls

- **Documentation** (`README.md`)
  - Complete usage instructions
  - Function reference with examples
  - Error code documentation
  - Use case examples
  - Quick start guide

### 🔧 Core Features

- ✅ Create time-bound events with descriptions
- ✅ Log unique participation per wallet address  
- ✅ Track participation order and rankings
- ✅ View user and contract-wide statistics
- ✅ Administrative event controls
- ✅ Participation proof generation

### 🎯 Learning Objectives

- Event logging patterns in Clarity
- Ensuring data uniqueness constraints
- Time-based smart contract logic
- Map data structure usage
- Access control implementation

### 🧪 Testing

Ready for testing with Clar




