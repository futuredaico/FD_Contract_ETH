const ProjectFactory = artifacts.require("ProjectFactory");
const TradeFundPool = artifacts.require("TradeFundPool");
const GovernFundPool = artifacts.require("GovernFundPool");

contract('ProjectFactory Test',(accounts)=>{
    it("should get 0 project count",async ()=>{
        let projectFactoryIns = await ProjectFactory.deployed();
        let count = await projectFactoryIns.getProjectCount();
        assert.equal(count,0,"count is not 0");
    });
    it("should create project correctly",async ()=>{
        let projectFactoryIns = await ProjectFactory.deployed();
        let tradeFundPool = await TradeFundPool.deployed();
        let governFundPool = await GovernFundPool.deployed();
        let r = await projectFactoryIns.createProject("NEL",tradeFundPool.address,governFundPool.address,{from:accounts[0]});
        let count = await projectFactoryIns.getProjectCount();
        let p = await projectFactoryIns.getProjectInfoByIndex(0);
        //console.log(p);
        assert.equal(count,1,"create project failed");
        assert.equal(p["tradeFundPoolAddress"],tradeFundPool.address,"create project failed");
        assert.equal(p["governFundPoolAddress"],governFundPool.address,"create project failed");
        assert.equal(p["creater"],accounts[0],"create project failed");
    })
});