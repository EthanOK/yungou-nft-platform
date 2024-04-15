# YunGou NFT Platform

`latest version: Excahnge_2.0`

This project demonstrates a basic Hardhat use case.

```
npm install @openzeppelin/contracts
npm install @openzeppelin/contracts-upgradeable
npm install dotenv --save
npm install --save-dev @nomiclabs/hardhat-etherscan
npm install --save-dev hardhat-contract-sizer
```

Try running some of the following tasks:

```shell
npx hardhat help

npx hardhat test

npx hardhat node

npx hardhat run scripts/deploy.js

npx hardhat verify --network goerli `contractAddress`
```

# YUNGOU Contracts

# 一、ETH MainNet

## （1）YUNGUO Platform Coin

### 1.YGM

https://etherscan.io/address/0x025d7D6df01074065B8Cfc9cb78456d417BBc6b7

### 2.YGME

https://etherscan.io/address/0x1b489201D974D37DDd2FaF6756106a7651914A63

### 3.YGIO

https://etherscan.io/address/0x19C996c4E4596aADDA9b7756B34bBa614376FDd4

## （2）YUNGUO Activity

### 1.YGM Convert YGME

https://etherscan.io/address/0x3db8480963a9333a7cda5338c9924e662f743170

### 2.YGME Staking(withdraw YGIO)

https://etherscan.io/address/0x1981f583D723bcbe7A0b41854afaDf7Fc287f11C

### 3.YGME Mint

https://etherscan.io/address/0xC1AE723ad98Af4E2D6EF3e384CBCD9CF4CeF8730

### 4.YunGou Dividend

https://etherscan.io/address/0x4643b06debe49fce229a77ebc9e7c5c036b2cedc

### 5.YGIO Convert V1

https://etherscan.io/address/0x4072D5CDd7Ba15de5a2681E42f4c7bC3a59B90FF

### 6.YunGou Swap

https://etherscan.io/address/0x8d393C25eCbB9B3059566BfC6d5c239F09EFb467

### 7.BatchTransferToken

https://etherscan.io/address/0xc384bb0a50ae21ea36b3d9d9864593915100d939

### 8.YunGou Convert V2

https://etherscan.io/address/0x191ad95bc373ea750dfbb791e8f2d204ef895cd9

## （3）NFT Exchange Platform

### 0.ProxyAdmin

https://etherscan.io/address/0xc07d62085ea1a66de2377e12a49e2410203d0a46

### 1.YUNGOU Exchange 1.0

1. UpgradeableProxy：

https://etherscan.io/address/0x8e319966F56E79C952C27C3991684E7e9B08Cd54

2. implementation contract：

https://etherscan.io/address/0x93b161ce690251f629ceae8ca1f69ab29e3eb77b#code

### 2.YUNGOU Exchange 2.0

Use [ImmutableCreate2Factory](https://etherscan.io/address/0x0000000000ffe8b47b3e2130213b802212439497#writeContract) Create Contracts

1. UpgradeableProxy

https://etherscan.io/address/0x0000006c517ed32ff128b33f137bb4ac31b0c6dd

2. implementation contract

https://etherscan.io/address/0x00000e14b01bffc5e55e11ff92b6d6b1156c5796#code

### 3.YunGouAggregators

Use [ImmutableCreate2Factory](https://etherscan.io/address/0x0000000000ffe8b47b3e2130213b802212439497#writeContract#F1) Create Contracts

1. MarketRegistry

   https://etherscan.io/address/0x0000c882f269b5ef434679cd0f50189abf19cb27

2. YunGouAggregators

   https://etherscan.io/address/0x0000007ee460b0928c2119e3b9747454a10d1557

# 二、BSC MainNet

## （1）YUNGUO Platform Coin

### 1.YGME

https://bscscan.com/address/0xe88e04e739eb73978e76b6a20a86643f2a0e364a

### 1.YGIO

https://bscscan.com/address/0xa2FCACCDCf80Ab826e3Da6831dA711E7c85C6F67

## （2）YUNGUO Activity

## （3）NFT Exchange Platform

### 1.ProxyAdmin

https://bscscan.com/address/0xc07d62085ea1a66de2377e12a49e2410203d0a46

### 2.YUNGOU Exchange 2.0

Use [ImmutableCreate2Factory](https://bscscan.com/address/0x0000000000ffe8b47b3e2130213b802212439497#writeContract#F1) Create Contracts

1. UpgradeableProxy

https://bscscan.com/address/0x0000006c517ed32ff128b33f137bb4ac31b0c6dd

2. implementation contract

https://bscscan.com/address/0x00000e14b01bffc5e55e11ff92b6d6b1156c5796

### 3.YunGouAggregators

Use [ImmutableCreate2Factory](https://etherscan.io/address/0x0000000000ffe8b47b3e2130213b802212439497#writeContract) Create Contracts

1. MarketRegistry

   https://bscscan.com/address/0x0000c882f269b5ef434679cd0f50189abf19cb27

2. YunGouAggregators

   https://bscscan.com/address/0x0000007ee460b0928c2119e3b9747454a10d1557

# 三、Cross Chain ETH-BSC

## （1）CrossChainYGInETH(YGME,YGIO)

https://etherscan.io/address/0xaB4803501d26364150a4d3Cd029b8354F6dc9f3D

## （2）CrossChainYGInBSC(YGME,YGIO)

https://bscscan.com/address/0xaB4803501d26364150a4d3Cd029b8354F6dc9f3D

# 四、Publish Collection

## （1）GoodMorningChongqing

https://etherscan.io/address/0x12eec80c93fce6bb5aab5bfa66d3c6e06ceb7ae1

# 五、YunGouNFTLaunch（Sepolia）

## （1）YunGouNFTLaunchFactory

https://sepolia.etherscan.io/address/0x49aa7aa6b3629eb175ef881c65ae0a506da00f00

## （2）ERC721DropCloneable_Implementation

https://sepolia.etherscan.io/address/0x643b06debe49fce229a77ebc9e7c5c036b2cedc
