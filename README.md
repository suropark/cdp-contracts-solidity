# cdp-contracts-solidity

Collateralized Debt Position (CDP) 주요 기능과

Collateral, Debt Value에 따라 커스텀 리워드를 설정, 지급할 수 있는 스마트 컨트랙트

## Features

-   Collateral Debt Position

-   Reward based on Collateral, Debt Value

### Contracts

    .contracts
    ├── governance/                   # Timelock, Multisig
    ├── incentives/                    # Incentive Contracts to handle reward logic
    ├── interfaces/                     # interfaces files
    ├── mock/                   #  Mock Contracts for testing
    ├── oracle/                   # Oracle Contracts
    ├── pool/                    # CDP Core Logic Contracts
    ├── token/                   # ERC20 Token Contracts
    └── ProtocolRegistry.sol    # Pool Registry contract
