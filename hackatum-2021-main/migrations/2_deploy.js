var Bank = artifacts.require("./Bank.sol")
module.exports = async function (deployer) {
    deployer.then(async () => {
        await deployer.deploy(Bank)
    })
}
