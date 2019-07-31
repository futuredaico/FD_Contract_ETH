const ProjectFactory = artifacts.require("ProjectFactory");
const FundPool = artifacts.require("FundPool");
const Vote = artifacts.require("Vote");

module.exports = function(deployer) {
    deployer.deploy(ProjectFactory);
    deployer.deploy(FundPool,30*24*60*60,Math.pow(10,20).toString(),1000*Math.pow(10,9),300,800);
    deployer.deploy(Vote);
    /*
    .then(()=>{
        FundPool.unsafe_setVote(Vote.address);
        Vote.unsafe_setFundPool(FundPool.address);
        ProjectFactory.createProject("NEL",FundPool.address,Vote.address);
    });
    */
};
