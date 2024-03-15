const hre = require("hardhat");

async function main() {
  const YGIOConvertV2 = await hre.ethers.getContractFactory("YGIOConvertV2");

  const _ygme = "0x1b489201D974D37DDd2FaF6756106a7651914A63";
  const _ygmeStaking = "0x1981f583D723bcbe7A0b41854afaDf7Fc287f11C";
  const _ygio = "0x19C996c4E4596aADDA9b7756B34bBa614376FDd4";
  const _signer = "0x5ab85B15e0ED0009A8AA606cb07809230fC16eaA";

  const inputData = YGIOConvertV2.getDeployTransaction(
    _ygme,
    _ygmeStaking,
    _ygio,
    _signer
  );

  console.log(inputData);

  const ygioConvert = await YGIOConvertV2.deploy(
    _ygme,
    _ygmeStaking,
    _ygio,
    _signer
  );

  await ygioConvert.deployed();

  console.log(`YGIOConvertV2 deployed to ${ygioConvert.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run scripts/deploy_YGIOConvertV2_E.js --network mainnet

// npx hardhat verify --network mainnet 0x191AD95bC373EA750dfbB791E8f2d204ef895cD9 0x1b489201D974D37DDd2FaF6756106a7651914A63 0x1981f583D723bcbe7A0b41854afaDf7Fc287f11C 0x19C996c4E4596aADDA9b7756B34bBa614376FDd4 0x5ab85B15e0ED0009A8AA606cb07809230fC16eaA
