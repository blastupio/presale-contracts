const hre = require('hardhat')
const { ethers } = hre

const TOKEN_DECIMALS = 6

async function deployToken() {
    const name = "TEST"
    const symbol = "TST"
    const totalSupply = ethers.parseEther("2850000000000")

    const args = [
        name,
        symbol,
        totalSupply,
        TOKEN_DECIMALS
    ]

    const contract = await ethers.deployContract("TokenCustomDecimalsMock", args)

    return contract
}

async function deployCoinPriceFeed() {
    const contract = await ethers.deployContract("CoinPriceFeedMock")

    return contract
}

async function deployPresale(
    COIN_PRICE_FEED,
    usdcToken,
    usdtToken,
    protocolWallet,
    admin,
    operator
) {

    const args = [
        COIN_PRICE_FEED,
        usdcToken,
        usdtToken,
        protocolWallet,
        admin,
        operator
    ]

    const contract = await ethers.deployContract("Presale", args)

    return contract
}

async function baseSetup(
    protocolWallet,
    admin,
    operator
) {
    const coinPriceFeed = await deployCoinPriceFeed()
    const token = await deployToken()

    const presale = await deployPresale(
            await coinPriceFeed.getAddress(), 
            await token.getAddress(),
            await token.getAddress(),
            protocolWallet,
            admin,
            operator
        )
    
    return { coinPriceFeed, token, presale }
}

module.exports = {
    baseSetup,
}