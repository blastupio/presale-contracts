const hre = require('hardhat')
const { ethers } = hre
const { expect, time, constants } = require('@1inch/solidity-utils')
const { baseSetup } = require('./helpers/deploy') 

describe('Presale test', function () {
    const ZERO_ADDRESS = constants.ZERO_ADDRESS

    const ONE_USDT = 1000000
    const ONE_ETH = ethers.parseEther("1")
    const TOKEN_PRECISION = 1e6
    const PRICE_FEED_PRECISION = 1e8

    let owner, user_1

    before(async function () {
        [owner, user_1] = await ethers.getSigners()
    })

    describe('Tests', function () {
        it("Method: updateProtocolWallet", async function() {
            const { priceFeed, token, presale } = await baseSetup(owner.address, owner.address)

            await presale.updateProtocolWallet(ZERO_ADDRESS)

            expect(await presale.protocolWallet()).to.be.eq(ZERO_ADDRESS)
        })

        it("Method: setStage", async function() {
            const { priceFeed, token, presale } = await baseSetup(owner.address, owner.address)

            expect(await presale.stageIterator()).to.be.eq(0)

            await presale.setStage(1)

            expect(await presale.stageIterator()).to.be.eq(1)        
        })

        it("Method: updateTotalSold", async function() {
            const { priceFeed, token, presale } = await baseSetup(owner.address, owner.address)

            expect(await presale.totalTokensSold()).to.be.eq(0)

            await presale.updateTotalSold(200)

            expect(await presale.totalTokensSold()).to.be.eq(200)
        })

        it("Method depositUSDT", async function() {
            const { priceFeed, token, presale } = await baseSetup(owner.address, owner.address)

            await token.approve(await presale.getAddress(), ONE_USDT * 2)

            await presale.depositUSDT(ONE_USDT * 2, ZERO_ADDRESS)

            expect(await presale.balances(owner.address)).to.be.eq(100)
        })

        it("Method depositUSDTTo", async function() {
            const { priceFeed, token, presale } = await baseSetup(owner.address, owner.address)

            await token.approve(await presale.getAddress(), ONE_USDT * 2)

            expect(await presale.totalTokensSold()).to.be.eq(0)

            await presale.depositUSDTTo(user_1.address, ONE_USDT * 2, ZERO_ADDRESS)

            expect(await presale.balances(user_1.address)).to.be.eq(100)
            expect(await presale.totalTokensSold()).to.be.eq(100)
            expect(await presale.totalSoldInUSD()).to.be.eq(ONE_USDT * 2 * (PRICE_FEED_PRECISION / TOKEN_PRECISION))
        })

        it("Method depositCoin", async function() {
            const { priceFeed, token, presale } = await baseSetup(owner.address, owner.address)

            await presale.depositCoin(ZERO_ADDRESS, {value: ONE_ETH})

            expect(await presale.balances(owner.address)).to.be.eq(104037)
        })

        it("Method depositCoinTo", async function() {
            const { priceFeed, token, presale } = await baseSetup(owner.address, owner.address)

            expect(await presale.totalTokensSold()).to.be.eq(0)

            await presale.depositCoinTo(user_1.address, ZERO_ADDRESS, {value: ONE_ETH})


            expect(await presale.balances(user_1.address)).to.be.eq(104037)
            expect(await presale.totalTokensSold()).to.be.eq(104037)
            expect(await presale.totalSoldInUSD()).to.be.eq(208074000000)
        })
    })
})