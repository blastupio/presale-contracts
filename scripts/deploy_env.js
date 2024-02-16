const hre = require('hardhat');
const { getChainId } = hre;

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

async function main() {
    const { deployer } = await getNamedAccounts();
    const Token = await ethers.deployContract("TokenCustomDecimalsMock", );
    
    const name = "USDT/USDC"
    const symbol = "TEST_TOKEN"
    const amount = 0
    const decimals = 6

    const args = [
        name,
        symbol,
        amount,
        decimals
    ]

    const token = await Token.deploy(
        name,
        symbol,
        amount,
        decimals
    );

    console.log("Contract Deployed to Address:", token.address);

    await sleep(10000)

    if (await getChainId() !== '31337') {
        await hre.run(`verify:verify`, {
            address: token.address,
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