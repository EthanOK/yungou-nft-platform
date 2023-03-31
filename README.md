# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a script that deploys that contract.

```
npm install @openzeppelin/contracts
npm install @openzeppelin/contracts-upgradeable
npm install dotenv --save
npm install --save-dev @nomiclabs/hardhat-etherscan
npm install --save-dev hardhat-contract-sizer
```

npx hardhat verify --network goerli `contractAddress`

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.js
```
