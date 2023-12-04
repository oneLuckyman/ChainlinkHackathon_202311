const fs = require("fs");
const path = require("path");
const {
  simulateScript,
  ReturnType,
  decodeResult,
  Location,
  CodeLanguage,
} = require("@chainlink/functions-toolkit");
const automatedFunctionsConsumerAbi = require("./automatedFunctions.json");   // 合约的 ABI 
const ethers = require("ethers");
require("@chainlink/env-enc").config();

const consumerAddress = "0x"
const subscriptionId = 1;

// 更新请求函数主体，包含网络信息
const updateRequestMumbai = async () => {
  // hardcoded for Polygon Mumbai
  const routerAddress = "0x6E2dc0F9DB014aE19888F539E59285D2Ea04244C";
  const donId = "fun-polygon-mumbai-1";
  const explorerUrl = "https://mumbai.polygonscan.com";

  // Initialize functions settings
  const source = fs
    .readFileSync(path.resolve(__dirname, "source.js"))
    .toString();

  const args = [];
  const gasLimit = 300000;

  // Initialize ethers signer and provider to interact with the contracts onchain
  const privateKey = process.env.PRIVATE_KEY; // fetch PRIVATE_KEY
  if (!privateKey)
    throw new Error(
      "private key not provided - check your environment variables"
    );

  const rpcUrl = process.env.POLYGON_MUMBAI_RPC_URL; // fetch mumbai RPC URL

  if (!rpcUrl)
    throw new Error(`rpcUrl not provided  - check your environment variables`);

  const provider = new ethers.providers.JsonRpcProvider(rpcUrl);

  const wallet = new ethers.Wallet(privateKey);
  const signer = wallet.connect(provider); // create ethers signer for signing transactions

  ///////// START SIMULATION ////////////

  console.log("Start simulation...");

  const response = await simulateScript({
    source: source,
    args: args,
    bytesArgs: [], // bytesArgs - arguments can be encoded off-chain to bytes.
    secrets: {}, // no secrets in this example
  });

  console.log("Simulation result", response);
  const errorString = response.errorString;
  if (errorString) {
    console.log(`❌ Error during simulation: `, errorString);
  } else {
    const returnType = ReturnType.uint256;
    const responseBytesHexstring = response.responseBytesHexstring;
    if (ethers.utils.arrayify(responseBytesHexstring).length > 0) {
      const decodedResponse = decodeResult(
        response.responseBytesHexstring,
        returnType
      );
      console.log(`✅ Decoded response to ${returnType}: `, decodedResponse);
    }
  }

  //////// MAKE REQUEST ////////

  console.log("\nMake request...");
  
  const functionsConsumer = new ethers.Contract(
    consumerAddress,
    functionsConsumerAbi,
    signer
  );

  const functionsRequestBytesHexString = buildRequestCBOR({
    codeLocation: Location.Inline, // Location of the source code - Only Inline is supported at the moment
    codeLanguage: CodeLanguage.JavaScript, // Code language - Only JavaScript is supported at the moment
    secretsLocation: Location.DONHosted, // Location of the encrypted secrets - DONHosted in this example
    source: source, // soure code
    args: args,
    bytesArgs: [], // bytesArgs - arguments can be encoded off-chain to bytes.
  });

  // Update request settings
  const transaction = await automatedFunctionsConsumer.updateRequest(
    functionsRequestBytesHexString,
    subscriptionId,
    gasLimit,
    ethers.utils.formatBytes32String(donId) // jobId is bytes32 representation of donId
  );

  // Log transaction details
  console.log(
    `\n✅ Automated Functions request settings updated! Transaction hash ${transaction.hash} - Check the explorer ${explorerUrl}/tx/${transaction.hash}`
  );
};

updateRequestMumbai().catch((e) => {
  console.error(e);
  process.exit(1);
});