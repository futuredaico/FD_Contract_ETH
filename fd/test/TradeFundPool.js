const AppManager = artifacts.require("AppManager");
const Co = artifacts.require("Co");
const FdToken = artifacts.require("FdToken");
const TradeFundPool = artifacts.require("TradeFundPool");

contract("TradeFundPool Test",async(accounts)=>{
    let root = accounts[0];
    let user1 = accounts[1];
    let crowdFundDuringTime= 30*24*60*60;
    let crowdFundMoney = 10**20;
    let crowdFundPrice = 223606000000000;
    let preMintAmount = 100;

    let tradeFundPoolIns , fdTokenIns , appManagerIns , coIns;
    let bytes32_FundPool_PreMint,bytes32_EMPTY_PARAM_HASH,bytes32_FdToken_Burn,FdToken_Mint;

    const init = async _ =>{
        tradeFundPoolIns = await TradeFundPool.deployed();
        fdTokenIns = await FdToken.deployed();
        appManagerIns = await AppManager.deployed();
        coIns = await Co.deployed();
        
        bytes32_EMPTY_PARAM_HASH = await tradeFundPoolIns.EMPTY_PARAM_HASH();
        bytes32_FundPool_PreMint = await tradeFundPoolIns.FundPool_PreMint();
        bytes32_FundPool_Start = await tradeFundPoolIns.FundPool_Start();
        bytes32_FdToken_Burn = await fdTokenIns.FdToken_Burn();
        bytes32_FdToken_Mint = await fdTokenIns.FdToken_Mint();
    
        ///分配权限
        await appManagerIns.addPermission(root,tradeFundPoolIns.address,bytes32_FundPool_PreMint);
        await appManagerIns.addPermission(root,tradeFundPoolIns.address,bytes32_FundPool_Start);
        await appManagerIns.addPermission(tradeFundPoolIns.address,fdTokenIns.address,bytes32_FdToken_Burn);
        await appManagerIns.addPermission(tradeFundPoolIns.address,fdTokenIns.address,bytes32_FdToken_Mint);
    }

    beforeEach(async ()=>{
        await init();
    });

    /// appManager 是否初始化正确
    it("appManager set correct in TradeFundPool",async()=>{
        let _appManagetInTradeFundPool = await tradeFundPoolIns.getAppManagerAddress();
        assert.equal(_appManagetInTradeFundPool,appManagerIns.address,"appManager set correct in TradeFundPool wrong");
    });

    /// 曲线 是否初始化正确
    it("Co set correct in TradeFundPool",async()=>{
        let _coInTradeFundPool = await tradeFundPoolIns.getCurveAddress();
        assert.equal(_coInTradeFundPool,coIns.address,"Co set correct in TradeFundPool wrong");
    });

    /// 股份货币 是否初始化正确
    it("FdToken set correct in TradeFundPool",async()=>{
        let _fdTokenInTradeFundPool = await tradeFundPoolIns.getFdTokenAddress();
        assert.equal(_fdTokenInTradeFundPool,fdTokenIns.address,"FdToken set correct in TradeFundPool wrong");
    });

    /// 验证参数是否正确
    it("check params",async()=>{
        let _crowdFundDuringTime = await tradeFundPoolIns.crowdFundDuringTime();
        let _crowdFundMoney = await tradeFundPoolIns.crowdFundMoney();
        let _crowdFundPrice = await tradeFundPoolIns.crowdFundPrice();
        let _started = await tradeFundPoolIns.started();
        assert.equal(_crowdFundDuringTime,crowdFundDuringTime,"crowdFundDuringTime is wrong");
        assert.equal(_crowdFundMoney,crowdFundMoney,"crowdFundMoney is wrong");
        assert.equal(_crowdFundPrice,crowdFundPrice,"crowdFundPrice is wrong");
        assert.equal(_started,false,"the game dont start");
    });
/*
    /////// 在游戏没有开始之前这些方法调用应该是失败的
    ///没开始之前不能众筹 -------这个应该报错
    it("cant crowdfunding before game start",async()=>{
        await tradeFundPoolIns.crowdfunding(false,{value:50*Math.pow(10,18),from:root});
    });
    ///没开始之前不能清退 -------这个应该报错
    it("cant windingUp before game start",async()=>{
        await tradeFundPoolIns.windingUp();
    });
    ///没开始之前不能购买 -------这个应该报错
    it("cant buy before game start",async()=>{
        await tradeFundPoolIns.buy({value:50*Math.pow(10,18),from:root});
    });
    ///没开始之前不能出售 -------这个应该报错
    it("cant sell before game start",async()=>{
        await tradeFundPoolIns.sell(100);
    });
    ///没开始之前不能投资 -------这个应该报错
    it("cant revenue before game start",async()=>{
        await tradeFundPoolIns.revenue({value:50*Math.pow(10,18),from:root});
    });
*/

    /// 在游戏没有开始之前 是允许预发行的
    it("can preMint before game start",async()=>{
        await tradeFundPoolIns.preMint(root,preMintAmount,{value:0,from:root});
        let _amount = await fdTokenIns.balanceOf(root);
        assert.equal(_amount,preMintAmount,"balance of user1 in fdt is wrong");
    });

    /// 开始一波游戏
    it("start the game",async()=>{
        let _started = await tradeFundPoolIns.started();
        assert.equal(_started,false,"the game dont start");

        await tradeFundPoolIns.start();

        _started = await tradeFundPoolIns.started();
        assert.equal(_started,true,"the game dont start");
    });
    /*
    /// 开始之后 是不允许预发行股份了 -------这个应该报错
    it("cant preMint after game start",async()=>{
        await tradeFundPoolIns.preMint(user1,100,{value:0,from:root});
    });

    //////////// 开始之后进入众筹期，此阶段有些方法是不能够调用的
    ///不能够购买
    it("cant buy when crowdfunding",async()=>{
        await tradeFundPoolIns.buy({value:50*Math.pow(10,18),from:root});
    });
    ///不能出售
    it("cant sell when crowdfunding",async()=>{
        await tradeFundPoolIns.sell(100);
    });
    ///不允许投资
    it("cant revenue when crowdfunding",async()=>{
        await tradeFundPoolIns.revenue({value:50*Math.pow(10,18),from:root});
    });
*/
    /// 先众筹购买50eth
    it("1 - crowd 50eth",async()=>{
        await tradeFundPoolIns.crowdfunding(false,{value:50*Math.pow(10,18),from:root});

        let balanceOfTradeFundPoolIns = await web3.eth.getBalance(tradeFundPoolIns.address); 
        assert.equal(balanceOfTradeFundPoolIns,50*Math.pow(10,18),"balanceOfTradeFundPoolIns is wrong");

        let sellReserve = await tradeFundPoolIns.sellReserve();
        assert.equal(sellReserve / 1,50* Math.pow(10,18) / 1000 * 300);

        let amount = 50 * Math.pow(10,18) / crowdFundPrice;
        amount = parseInt(amount);
        let balanceOfFdt = await fdTokenIns.balanceOf(root);
        assert(balanceOfFdt.toNumber(),amount,"balance of fdt is wrong");
    });

    /*
    /// 再众筹买个50eth 此时应该触发了众筹结束
    it("2-1 - crowd 50eth",async()=>{
        await tradeFundPoolIns.crowdfunding(false,{value:50*Math.pow(10,18),from:root});

        let balanceOfTradeFundPoolIns = await web3.eth.getBalance(tradeFundPoolIns.address); 
        assert.equal(balanceOfTradeFundPoolIns,100*Math.pow(10,18),"balanceOfTradeFundPoolIns is wrong");

        let sellReserve = await tradeFundPoolIns.sellReserve();
        assert.equal(sellReserve / 1,100 * Math.pow(10,18)  / 1000 * 300);

        let amount = 50 * Math.pow(10,18) / crowdFundPrice;
        amount = parseInt(amount);
        let balanceOfFdt = await fdTokenIns.balanceOf(root);
        assert(balanceOfFdt.toNumber(),amount + amount,"balance of fdt is wrong");

        let during_crowdfunding = await tradeFundPoolIns.during_crowdfunding();
        assert(during_crowdfunding == false,true,"crowdfunding end");
    });
    */

    /*
    /// 再众筹个70eth  超出的20eth要求返还
    it("2-2 - crowd 70eth , 20eth back",async()=>{
        let balanceOfRoot_before = await web3.eth.getBalance(root);
        //console.log(balanceOfRoot_before);
        await tradeFundPoolIns.crowdfunding(true,{value:70*Math.pow(10,18),from:root});
        let balanceOfTradeFundPoolIns = await web3.eth.getBalance(tradeFundPoolIns.address); 
        assert.equal(balanceOfTradeFundPoolIns,100*Math.pow(10,18),"balanceOfTradeFundPoolIns is wrong");

        //因为root还支付了系统费，所以要花了50eth+  但肯定没有花到51eth，这里主要是测试有没有把70超出的部分返还
        let balanceOfRoot_after = await web3.eth.getBalance(root);
        //console.log(balanceOfRoot_after);
        assert.equal(balanceOfRoot_after - balanceOfRoot_before < 51*Math.pow(10,18),true,"balance of root is wrong");

        let sellReserve = (await tradeFundPoolIns.sellReserve()) / 1;
        console.log(sellReserve);
        let _s = 100 * Math.pow(10,18)  / 1000 * 300;
        console.log(_s);
        assert.equal(sellReserve == _s,true,"sellReserve is wrong");

        let amount = 50 * Math.pow(10,18) / crowdFundPrice;
        amount = parseInt(amount);
        let balanceOfFdt = await fdTokenIns.balanceOf(root);
        console.log(balanceOfFdt.toNumber());
        console.log(amount);
        assert(balanceOfFdt.toNumber() == amount + amount,true,"balance of fdt is wrong");

        let during_crowdfunding = await tradeFundPoolIns.during_crowdfunding();
        assert(during_crowdfunding == false,true,"crowdfunding end");
    });
    */

    /// 众筹个70eth 并且超出的20eth 不要求返还
    it("2-3 - crowd 70eth, 20eth dont need back",async()=>{
        let balanceOfRoot_before = await web3.eth.getBalance(root);

        await tradeFundPoolIns.crowdfunding(false,{value:70*Math.pow(10,18),from:root});
        let balanceOfTradeFundPoolIns = await web3.eth.getBalance(tradeFundPoolIns.address); 
        assert.equal(balanceOfTradeFundPoolIns,120*Math.pow(10,18),"balanceOfTradeFundPoolIns is wrong");

        //因为root还支付了系统费，所以要花了70eth+  但肯定没有花到71eth
        let balanceOfRoot_after = await web3.eth.getBalance(root);
        assert.equal(balanceOfRoot_after - balanceOfRoot_before < 71*Math.pow(10,18),true,"balance of root is wrong");

        let sellReserve = await tradeFundPoolIns.sellReserve();
        assert.equal(sellReserve / 1 == 120 * Math.pow(10,18)  / 1000 * 300, true,"sellReserve is wrong");

        let amount = 50 * Math.pow(10,18) / crowdFundPrice;
        amount = parseInt(amount);
        let balanceOfFdt = (await fdTokenIns.balanceOf(root))/1;
        let curTotal = amount + amount + preMintAmount;
        //还有20eth是通过曲线购买的  42684
        let amount2 =parseInt(Math.sqrt(2 * 20 * Math.pow(10,18) / Math.pow(10,9) + curTotal * curTotal))- curTotal;
        assert.equal(balanceOfFdt == (curTotal + amount2),true,"balance of fdt is wrong");

        let during_crowdfunding = await tradeFundPoolIns.during_crowdfunding();
        assert.equal(during_crowdfunding == false,true,"crowdfunding end");
    });

    /// 再买个30eth
    it("buy 30eth",async()=>{
        let balanceOfRoot_before = await web3.eth.getBalance(root);
        await tradeFundPoolIns.buy({from:root,value:30 * Math.pow(10,18)});
        let balanceOfTradeFundPoolIns = await web3.eth.getBalance(tradeFundPoolIns.address); 
        assert.equal(balanceOfTradeFundPoolIns,150*Math.pow(10,18),"balanceOfTradeFundPoolIns is wrong");

        //因为root还支付了系统费，所以要花了30eth+  但肯定没有花到31eth
        let balanceOfRoot_after = await web3.eth.getBalance(root);
        assert.equal(balanceOfRoot_after - balanceOfRoot_before < 31*Math.pow(10,18),true,"balance of root is wrong");

        let sellReserve = await tradeFundPoolIns.sellReserve();
        assert.equal(sellReserve / 1 == 150 * Math.pow(10,18)  / 1000 * 300, true,"sellReserve is wrong");
    });
});