const hre = require('hardhat');
const { getChainId, network } = hre;

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

module.exports = async ({ getNamedAccounts, deployments }) => {
    console.log("running deploy presale script");
    console.log("network name: ", network.name);
    console.log("network id: ", await getChainId())

    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

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

    const presale = await deploy('PresaleBSC', {
        from: deployer,
        args: args
    })

    console.log("PresaleBSC deployed to: ", presale.address)

    await sleep(10000)

    if (await getChainId() !== '31337') {
        await hre.run(`verify:verify`, {
            address: presale.address,
            constructorArguments: args
        })
    }
};

module.exports.tags = ['PresaleBSC'];
