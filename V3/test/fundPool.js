const ProjectFactory = artifacts.require("ProjectFactory");
const FundPool = artifacts.require("FundPool");
const Vote = artifacts.require("Vote");

contract("FundPool Test",async(accounts)=>{

    it("should correct params",async ()=>{
        let fundPoolIns = await FundPool.deployed();
        let d = await fundPoolIns.crowdFundDuringTime();
        let m = await fundPoolIns.crowdFundMoney();
        let s = await fundPoolIns.slope();
        let a = await fundPoolIns.alpha();
        let b = await fundPoolIns.beta();
        let p = await fundPoolIns.crowdFundPrice();
        let _p = Math.sqrt(2 * m * 1000  / s );
        _p = parseInt(parseInt(_p) / 2) * s / 1000 ;
        console.log(p.toString());
        console.log(_p);
        assert.equal(d,30*24*60*60,"d is worng");
        assert.equal(m,Math.pow(10,20),"m is worng");
        assert.equal(s,1000 * Math.pow(10,9),"s is worng");
        assert.equal(a,300,"a is worng");
        assert.equal(b,800,"b is worng");
        assert.equal(p,_p,"p is worng");
    });

    it("should set vote correctly",async ()=>{
        let fundPoolIns = await FundPool.deployed();
        let voteIns = await Vote.deployed();
        await fundPoolIns.unsafe_setVote(voteIns.address);
        let address = await fundPoolIns.getVoteContract();
        assert.equal(address,voteIns.address,"set vote failed");
    })

    it("should the game hasn't started yet", async ()=>{
        let fundPoolIns = await FundPool.deployed();
        let started = await fundPoolIns.started();
        assert.equal(started,false,"fund cant be start");
    });

    it("should start the game",async ()=>{
        let fundPoolIns = await FundPool.deployed();
        await fundPoolIns.start({from:accounts[0]});
        let started = await fundPoolIns.started();
        assert.equal(started,true,"start failed");
    });

    it("should Crowdfunding 50 eth",async ()=>{
        let fundPoolIns = await FundPool.deployed();
        await fundPoolIns.crowdfunding(false,{value:50*Math.pow(10,18)});
        let sellReserve = await fundPoolIns.sellReserve();
        let totalSendToVote = await fundPoolIns.totalSendToVote();
        //console.log(sellReserve.toString());
        //console.log(totalSendToVote.toString());
        let balance_fund = await fundPoolIns.getBalance();
        console.log("balance_fund:"+balance_fund.toString());
        assert.equal(balance_fund,50*Math.pow(10,18),"fundPoolIns balance wrong");
        assert.equal(sellReserve,15*1000*Math.pow(10,18),"sellReserve is worng");
        assert.equal(totalSendToVote,35*1000*Math.pow(10,18),"sellReserve is worng");

    });

    it("should Crowdfunding 50 eth",async ()=>{
        let fundPoolIns = await FundPool.deployed();
        let voteIns = await Vote.deployed();
        await fundPoolIns.crowdfunding(false,{value:50*Math.pow(10,18)});
        let sellReserve = await fundPoolIns.sellReserve();
        let totalSendToVote = await fundPoolIns.totalSendToVote();
        //console.log(sellReserve.toString());
        //console.log(totalSendToVote.toString());
        let balance_fund = await fundPoolIns.getBalance();
        let balance_vote = await voteIns.getBalance();
        console.log("balance_fund:"+balance_fund.toString());
        console.log("balance_vote:"+balance_vote.toString());
        assert.equal(sellReserve,30*1000*Math.pow(10,18),"sellReserve is worng");
        assert.equal(totalSendToVote,70*1000*Math.pow(10,18),"sellReserve is worng");
        assert.equal(balance_fund,30*Math.pow(10,18),"fund balance is wrong");
        assert.equal(balance_vote,70*Math.pow(10,18),"vote balance is wrong");
    });
});