const { ethers } = require("ethers");

async function getEncodedDataAndhashData(orderId, account, amount) {
  const type = ["uint256", "address", "uint256"];
  const args = [orderId, account, amount];

  const encodedData = ethers.utils.defaultAbiCoder.encode(type, args);

  const hashData = ethers.utils.keccak256(encodedData);

  return [encodedData, hashData];
}
async function getSignature(hashData, signer) {
  let binaryData_ = ethers.utils.arrayify(hashData);

  let signPromise_ = signer.signMessage(binaryData_);
  return signPromise_;
}
async function main() {
  //   let privateKey = "";
  //   let signer = new ethers.Wallet(privateKey);
  let signer = ethers.Wallet.createRandom();
  let otherAccount = ethers.Wallet.createRandom();
  let [encodedData, hashData] = await getEncodedDataAndhashData(
    1,
    otherAccount.address,
    10000000
  );
  console.log(encodedData);
  console.log(hashData);

  const signature = await getSignature(hashData, signer);
  console.log(signature);
}
main();
