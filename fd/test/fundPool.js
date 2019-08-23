const ProjectFactory = artifacts.require("ProjectFactory");
const TradeFundPool = artifacts.require("TradeFundPool");
const VoteFundPool = artifacts.require("VoteFundPool");

contract("TradeFundPool Test",async(accounts)=>{

    it("should correct params",async ()=>{
        let tradeFundPoolIns = await TradeFundPool.deployed();
        let d = await tradeFundPoolIns.crowdFundDuringTime();
        let m = await tradeFundPoolIns.crowdFundMoney();
        let s = await tradeFundPoolIns.slope();
        let a = await tradeFundPoolIns.alpha();
        let b = await tradeFundPoolIns.beta();
        let p = await tradeFundPoolIns.crowdFundPrice();
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
        let tradeFundPoolIns = await TradeFundPool.deployed();
        let voteFundPoolIns = await VoteFundPool.deployed();
        await tradeFundPoolIns.unsafe_setVote(voteFundPoolIns.address);
        let address = await tradeFundPoolIns.getVoteContract();
        assert.equal(address,voteFundPoolIns.address,"set vote failed");
    })

    it("should the game hasn't started yet", async ()=>{
        let tradeFundPoolIns = await TradeFundPool.deployed();
        let started = await tradeFundPoolIns.started();
        assert.equal(started,false,"fund cant be start");
    });

    it("should start the game",async ()=>{
        let tradeFundPoolIns = await TradeFundPool.deployed();
        await tradeFundPoolIns.start({from:accounts[0]});
        let started = await tradeFundPoolIns.started();
        assert.equal(started,true,"start failed");
    });

    it("should Crowdfunding 50 eth",async ()=>{
        let tradeFundPoolIns = await TradeFundPool.deployed();
        await tradeFundPoolIns.crowdfunding(false,{value:50*Math.pow(10,18)});
        let sellReserve = await tradeFundPoolIns.sellReserve();
        let totalSendToVote = await tradeFundPoolIns.totalSendToVote();
        //console.log(sellReserve.toString());
        //console.log(totalSendToVote.toString());
        let balance_fund = await tradeFundPoolIns.getBalance();
        console.log("balance_fund:"+balance_fund.toString());
        assert.equal(balance_fund,50*Math.pow(10,18),"tradeFundPoolIns balance wrong");
        assert.equal(sellReserve,15*1000*Math.pow(10,18),"sellReserve is worng");
        assert.equal(totalSendToVote,35*1000*Math.pow(10,18),"sellReserve is worng");

    });

    it("should Crowdfunding 50 eth",async ()=>{
        let tradeFundPoolIns = await TradeFundPool.deployed();
        let voteFundPoolIns = await VoteFundPool.deployed();
        await tradeFundPoolIns.crowdfunding(false,{value:50*Math.pow(10,18)});
        let sellReserve = await tradeFundPoolIns.sellReserve();
        let totalSendToVote = await tradeFundPoolIns.totalSendToVote();
        //console.log(sellReserve.toString());
        //console.log(totalSendToVote.toString());
        let balance_fund = await tradeFundPoolIns.getBalance();
        let balance_vote = await voteFundPoolIns.getBalance();
        console.log("balance_fund:"+balance_fund.toString());
        console.log("balance_vote:"+balance_vote.toString());
        assert.equal(sellReserve,30*1000*Math.pow(10,18),"sellReserve is worng");
        assert.equal(totalSendToVote,70*1000*Math.pow(10,18),"sellReserve is worng");
        assert.equal(balance_fund,30*Math.pow(10,18),"fund balance is wrong");
        assert.equal(balance_vote,70*Math.pow(10,18),"vote balance is wrong");
    });
});