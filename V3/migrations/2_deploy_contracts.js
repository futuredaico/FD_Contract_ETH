const ProjectFactory = artifacts.require("ProjectFactory");
const TradeFundPool = artifacts.require("TradeFundPool");
const GovernFundPool = artifacts.require("GovernFundPool");

module.exports = function(deployer) {
    deployer.deploy(ProjectFactory);
    deployer.deploy(TradeFundPool,30*24*60*60,Math.pow(10,20).toString(),1000*Math.pow(10,9),300,800);
    deployer.deploy(GovernFundPool);
    /*
    .then(()=>{
        FundPool.unsafe_setVote(Vote.address);
        Vote.unsafe_setFundPool(FundPool.address);
        ProjectFactory.createProject("NEL",FundPool.address,Vote.address);
    });
    */
};
