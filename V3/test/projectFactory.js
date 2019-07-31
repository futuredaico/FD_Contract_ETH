const ProjectFactory = artifacts.require("ProjectFactory");
const FundPool = artifacts.require("FundPool");
const Vote = artifacts.require("Vote");

contract('ProjectFactory Test',(accounts)=>{
    it("should get 0 project count",async ()=>{
        let projectFactoryIns = await ProjectFactory.deployed();
        let count = await projectFactoryIns.getProjectCount();
        assert.equal(count,0,"count is not 0");
    });
    it("should create project correctly",async ()=>{
        let projectFactoryIns = await ProjectFactory.deployed();
        let fundPool = await FundPool.deployed();
        let vote = await Vote.deployed();
        let r = await projectFactoryIns.createProject("NEL",fundPool.address,vote.address,{from:accounts[0]});
        let count = await projectFactoryIns.getProjectCount();
        let p = await projectFactoryIns.getProjectInfoByIndex(0);
        //console.log(p);
        assert.equal(count,1,"create project failed");
        assert.equal(p["fundPoolContract"],fundPool.address,"create project failed");
        assert.equal(p["voteContract"],vote.address,"create project failed");
        assert.equal(p["creater"],accounts[0],"create project failed");
    })
});