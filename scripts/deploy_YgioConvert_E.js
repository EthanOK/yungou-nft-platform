const hre = require("hardhat");

async function main() {
  const YgioConvert = await hre.ethers.getContractFactory("YgioConvert");
  // address _ygme,
  // address _ygmeStaking,
  // address _ygio,
  // address _signer
  const _ygme_E = "0x1b489201D974D37DDd2FaF6756106a7651914A63";
  const _ygmeStaking_E = "0x1981f583D723bcbe7A0b41854afaDf7Fc287f11C";
  const _ygio_E = "0x19C996c4E4596aADDA9b7756B34bBa614376FDd4";
  const _signer_E = "0x5ab85B15e0ED0009A8AA606cb07809230fC16eaA";

  const ygioConvert = await YgioConvert.deploy(
    _ygme_E,
    _ygmeStaking_E,
    _ygio_E,
    _signer_E
  );

  await ygioConvert.deployed();

  console.log(`YgmeMint deployed to ${ygioConvert.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run scripts/deploy_YgioConvert_E.js --network mainnet

// npx hardhat verify --network mainnet 0x4072D5CDd7Ba15de5a2681E42f4c7bC3a59B90FF 0x1b489201D974D37DDd2FaF6756106a7651914A63 0x1981f583D723bcbe7A0b41854afaDf7Fc287f11C 0x19C996c4E4596aADDA9b7756B34bBa614376FDd4 0x5ab85B15e0ED0009A8AA606cb07809230fC16eaA
