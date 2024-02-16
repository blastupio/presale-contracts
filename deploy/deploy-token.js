const hre = require('hardhat');
const { getChainId } = hre;

module.exports = async ({ getNamedAccounts, deployments }) => {
    console.log("running deploy Token script");
    console.log("network name: ", network.name);
    console.log("network id: ", await getChainId())

    function sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    {
        console.log("Deploy token");

        const name = "TEST_USDT/USDC"
        const symbol = "TEST_TOKEN"
        const amount = 0
        const decimals = 6
        
        const args = [
            name,
            symbol,
            amount,
            decimals
        ]
    
        const token = await deploy('TokenCustomDecimalsMock', {
            from: deployer,
            args
        })
    
        console.log("TokenCustomDecimalsMock deployed to: ", token.address)

        await sleep(10000)
    
        if (await getChainId() !== '31337') {
            await hre.run(`verify:verify`, {
                address: token.address,
                constructorArguments: args
            })
        }
    }
};

module.exports.tags = ['Token'];
