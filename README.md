# 👗 Swap-to-Earn Wardrobe App

A blockchain-powered sustainable fashion platform where users swap second-hand clothes and earn reward tokens for every verified swap! 🌱

## 🌟 Features

- **User Registration**: Create your profile and join the sustainable fashion community
- **Clothing Listings**: Add your unwanted clothes with detailed descriptions and photos
- **Smart Swaps**: Propose and accept clothing swaps with other users
- **Reward Tokens**: Earn SWR tokens for every completed swap
- **Reputation System**: Build your reputation through successful swaps
- **Item Management**: Control availability and track your items

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- [Stacks Wallet](https://www.hiro.so/wallet) for interacting with the contract

### Installation

1. Clone this repository
2. Navigate to the project directory
3. Run `clarinet check` to verify the contract

## 📋 Smart Contract Functions

### Public Functions

#### 🔐 User Management
- `register-user(username)`: Register as a new user
- `get-user(user)`: Get user profile information

#### 👕 Item Management
- `add-clothing-item(title, description, category, size, condition, image-url)`: List a new clothing item
- `set-item-availability(item-id, available)`: Toggle item availability
- `get-item(item-id)`: Get item details
- `get-user-items(user)`: Get all items owned by a user

#### 🔄 Swap Operations
- `create-swap-proposal(initiator-item-id, responder-item-id)`: Propose a swap
- `accept-swap(swap-id)`: Accept a pending swap proposal
- `reject-swap(swap-id)`: Reject a pending swap proposal
- `complete-swap(swap-id)`: Complete an accepted swap and mint rewards
- `get-swap(swap-id)`: Get swap details

#### 🪙 Token Operations (SIP-010 Compatible)
- `transfer(amount, sender, recipient, memo)`: Transfer SWR tokens
- `get-balance(who)`: Check token balance
- `get-total-supply()`: Get total token supply

### Owner Functions
- `set-reward-amount(new-amount)`: Update reward amount per swap

## 🎮 Usage Example

1. **Register**: `(contract-call? .swap-to-earn-wardrobe register-user "fashionista123")`

2. **Add Item**: 
   ```clarity
   (contract-call? .swap-to-earn-wardrobe add-clothing-item 
       "Vintage Denim Jacket" 
       "Classic blue denim jacket from the 90s" 
       "Jackets" 
       "M" 
       "Good" 
       "https://example.com/jacket.jpg")
   ```

3. **Create Swap**: `(contract-call? .swap-to-earn-wardrobe create-swap-proposal u1 u2)`

4. **Accept Swap**: `(contract-call? .swap-to-earn-wardrobe accept-swap u1)`

5. **Complete Swap**: `(contract-call? .swap-to-earn-wardrobe complete-swap u1)`

## 💰 Reward System

- **Base Reward**: 100 SWR tokens per completed swap (1.0 SWR with 6 decimals)
- **Reputation**: +10 reputation points per completed swap
- **Tracking**: Total swaps and reputation tracked per user

## 📊 Data Structure

### Users
- Username, reputation score, total swaps completed, join date

### Clothing Items  
- Owner, title, description, category, size, condition, image URL, availability

### Swaps
- Participants, items involved, status, timestamps

## 🔧 Contract Constants

- **Reward per swap**: 100,000,000 micro-SWR (1.0 SWR)
- **Token decimals**: 6
- **Max items per user**: 100

## 🌍 Sustainability Impact

Every swap prevents clothing waste and reduces environmental impact while rewarding users for sustainable choices! 🌱♻️

## 🛠️ Development

Run tests: `clarinet test`
Check contract: `clarinet check`
Deploy: `clarinet deploy`

## 📝 License

This project is open source and available under the MIT License.
