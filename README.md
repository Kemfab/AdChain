# AdChain

A privacy-focused digital advertising platform where users opt-in to view ads and receive direct compensation without intermediaries.

## Overview

AdChain is a Clarity smart contract that enables a decentralized advertising ecosystem on the Stacks blockchain. It allows users to control their ad preferences while receiving direct compensation for viewing ads, and enables advertisers to create targeted campaigns without compromising user privacy.

## Features

- **User Privacy Control**: Users opt-in to view ads and set their preferences
- **Direct Compensation**: Users receive STX tokens directly for viewing ads
- **No Intermediaries**: Advertisers connect directly with users
- **Transparent Fee Structure**: Small platform fee to sustain the ecosystem
- **Campaign Management**: Advertisers can create, pause, and manage ad campaigns

## Contract Functions

### User Functions

- `register-user`: Register as a new user with ad preferences
- `update-preferences`: Update your ad category preferences
- `opt-out`: Temporarily opt-out of receiving ads
- `opt-in`: Re-enable ad viewing after opting out
- `record-ad-view`: Record that you've viewed an ad and receive compensation
- `withdraw-earnings`: Withdraw your earned STX tokens

### Advertiser Functions

- `create-ad-campaign`: Create a new advertising campaign
- `pause-campaign`: Temporarily pause an active campaign
- `resume-campaign`: Resume a paused campaign
- `add-campaign-budget`: Add more budget to an existing campaign

### Admin Functions

- `set-contract-owner`: Update the contract administrator
- `set-platform-fee`: Adjust the platform fee percentage
- `add-category`: Add a new ad category
- `withdraw-platform-fees`: Withdraw accumulated platform fees

### Read-Only Functions

- `get-user-profile`: View a user's profile and preferences
- `get-campaign`: Get details about an ad campaign
- `get-category`: Get information about an ad category
- `get-platform-fee`: Check the current platform fee percentage
- `get-platform-balance`: View the accumulated platform fees
- `get-ad-view`: Check if a user has viewed a specific ad

## How It Works

1. **For Users**:
   - Register with your ad preferences
   - View ads that match your preferences
   - Automatically receive STX tokens for each ad view
   - Withdraw your earnings anytime

2. **For Advertisers**:
   - Create campaigns with a budget and cost-per-view
   - Target specific interest categories
   - Pay only when users actually view your ads
   - Manage campaigns with pause/resume functionality

## Privacy Features

- Users only see ads matching their stated preferences
- No tracking or data collection beyond what's necessary
- Users can opt-out at any time
- All interactions are pseudonymous via blockchain addresses

## Development

This contract is developed using Clarity and can be tested with Clarinet.