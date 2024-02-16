const hre = require('hardhat');
const { getChainId } = hre;

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

async function main() {
    const [deployer] = await ethers.getSigners();
    const Presale = await ethers.deployContract("Presale", );
    
    const coinPriceFeed = process.env.COIN_PRICE_FEED
    const usdcToken = process.env.USDC_TOKEN
    const usdtToken = process.env.USDT_TOKEN
    const protocolWallet = process.env.PROTOCOL_WALLET
    const admin = process.env.PUBLIC_KEY_ADMIN

    const args = [
        coinPriceFeed,
        usdcToken,
        usdtToken,
        protocolWallet,
        admin
    ]

    const presale = await Presale.deploy(
        coinPriceFeed,
        usdcToken,
        usdtToken,
        protocolWallet,
        admin    
    );

    console.log("Contract Deployed to Address:", presale.address);

    await sleep(10000)

    if (await getChainId() !== '31337') {
        await hre.run(`verify:verify`, {
            address: presale.address,
            constructorArguments: args
        })
    }
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });