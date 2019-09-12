const AppManager = artifacts.require("AppManager");
const Co = artifacts.require("Co");
const FdToken = artifacts.require("FdToken");
const TradeFundPool = artifacts.require("TradeFundPool");
const GovernShareManager = artifacts.require("GovernShareManager");
const Vote_ApplyFund = artifacts.require("Vote_ApplyFund");
const DateTime = artifacts.require("DateTime");

class Ut {
    /**
    * 异步延迟
    * @param {number} time 延迟的时间,单位毫秒
    */
    static sleep(time = 0) {
      return new Promise((resolve, reject) => {
        setTimeout(() => {
          resolve();
        }, time);
      })
    };
}

contract("Test",async(accounts)=>{
    let root = accounts[0];
    let user1 = accounts[1];
    let user2 = accounts[2];
    let crowdFundDuringTime= 30*24*60*60;
    let crowdFundMoney = 10**20;
    let crowdFundPrice = 223606000000000;
    let preMintAmount = 100;

    let tradeFundPoolIns , fdTokenIns , appManagerIns , coIns , governShareManagerIns , vote_ApplyFundIns ,DateTimeIns;
    let bytes32_FundPool_PreMint,bytes32_EMPTY_PARAM_HASH,bytes32_FdToken_Burn,bytes32_FdToken_Mint,bytes32_FundPool_Start,bytes32_GovernShareManager_Lock,
        bytes32_Vote_ApplyFund_OneTicketRefuseProposal;

    it("init",async()=>{
        tradeFundPoolIns = await TradeFundPool.deployed();
        fdTokenIns = await FdToken.deployed();
        appManagerIns = await AppManager.deployed();
        coIns = await Co.deployed();
        governShareManagerIns = await GovernShareManager.deployed();
        vote_ApplyFundIns = await Vote_ApplyFund.deployed();
        DateTimeIns = await DateTime.deployed();
        
        bytes32_EMPTY_PARAM_HASH = await tradeFundPoolIns.EMPTY_PARAM_HASH();
        bytes32_FundPool_PreMint = await tradeFundPoolIns.FundPool_PreMint();
        bytes32_FundPool_Start = await tradeFundPoolIns.FundPool_Start();
        bytes32_FdToken_Burn = await fdTokenIns.FdToken_Burn();
        bytes32_FdToken_Mint = await fdTokenIns.FdToken_Mint();
        bytes32_GovernShareManager_Lock = await governShareManagerIns.GovernShareManager_Lock();
        bytes32_Vote_ApplyFund_OneTicketRefuseProposal = await vote_ApplyFundIns.Vote_ApplyFund_OneTicketRefuseProposal();

        await appManagerIns.initialize(tradeFundPoolIns.address,governShareManagerIns.address,fdTokenIns.address,DateTimeIns.address);
    
        ///分配权限
        await appManagerIns.addPermission(root,tradeFundPoolIns.address,bytes32_FundPool_PreMint);
        await appManagerIns.addPermission(root,root,bytes32_Vote_ApplyFund_OneTicketRefuseProposal);
        await appManagerIns.addPermission(root,tradeFundPoolIns.address,bytes32_FundPool_Start);
        await appManagerIns.addPermission(tradeFundPoolIns.address,fdTokenIns.address,bytes32_FdToken_Burn);
        await appManagerIns.addPermission(tradeFundPoolIns.address,fdTokenIns.address,bytes32_FdToken_Mint);
        await appManagerIns.addPermission(vote_ApplyFundIns.address,governShareManagerIns.address,bytes32_GovernShareManager_Lock);
    });

    /*
    const init = async _ =>{
        tradeFundPoolIns = await TradeFundPool.deployed();
        fdTokenIns = await FdToken.deployed();
        appManagerIns = await AppManager.deployed();
        coIns = await Co.deployed();
        governShareManagerIns = await GovernShareManager.deployed();
        
        bytes32_EMPTY_PARAM_HASH = await tradeFundPoolIns.EMPTY_PARAM_HASH();
        bytes32_FundPool_PreMint = await tradeFundPoolIns.FundPool_PreMint();
        bytes32_FundPool_Start = await tradeFundPoolIns.FundPool_Start();
        bytes32_FdToken_Burn = await fdTokenIns.FdToken_Burn();
        bytes32_FdToken_Mint = await fdTokenIns.FdToken_Mint();
        console.log(1);

        await appManagerIns.initialize(tradeFundPoolIns.address,governShareManagerIns.address,fdTokenIns.address);
    
        ///分配权限
        await appManagerIns.addPermission(root,tradeFundPoolIns.address,bytes32_FundPool_PreMint);
        await appManagerIns.addPermission(root,tradeFundPoolIns.address,bytes32_FundPool_Start);
        await appManagerIns.addPermission(tradeFundPoolIns.address,fdTokenIns.address,bytes32_FdToken_Burn);
        await appManagerIns.addPermission(tradeFundPoolIns.address,fdTokenIns.address,bytes32_FdToken_Mint);
    }

    beforeEach(async ()=>{
        await init();
    });
    */

    /// appManager 中的几个合约地址是否是正确的
    it("params set correct in appManager",async()=>{
        let _address_governShareManager = await appManagerIns.getGovernShareManager();
        let _address_tradeFundPool = await appManagerIns.getTradeFundPool();
        let _address_fdToken = await appManagerIns.getFdToken();
        assert.equal(_address_governShareManager == governShareManagerIns.address,true,"_address_governShareManager is wrong");
        assert.equal(_address_tradeFundPool == tradeFundPoolIns.address,true,"_address_tradeFundPool is wrong");
        assert.equal(_address_fdToken == fdTokenIns.address,true,"_address_fdToken is wrong");
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
        let amountOfFdToken_before = (await fdTokenIns.balanceOf(root)) / 1;
        let totalSupply_before = (await fdTokenIns.totalSupply()) / 1;
        await tradeFundPoolIns.buy({from:root,value:30 * Math.pow(10,18)});
        let balanceOfTradeFundPoolIns = await web3.eth.getBalance(tradeFundPoolIns.address);
        assert.equal(balanceOfTradeFundPoolIns,150*Math.pow(10,18),"balanceOfTradeFundPoolIns is wrong");
        let amountOfFdToken_after = (await fdTokenIns.balanceOf(root))/1;
        //因为root还支付了系统费，所以要花了30eth+  但肯定没有花到31eth
        let balanceOfRoot_after = await web3.eth.getBalance(root);
        assert.equal(balanceOfRoot_after - balanceOfRoot_before < 31 * Math.pow(10,18),true,"balance of root is wrong");

        let amount = parseInt(Math.sqrt(2 * 30 * Math.pow(10,18) / Math.pow(10,9) + totalSupply_before * totalSupply_before))- totalSupply_before;
        assert.equal(amountOfFdToken_after - amountOfFdToken_before,amount,"amount is wrong");

        let sellReserve = await tradeFundPoolIns.sellReserve();
        assert.equal(sellReserve / 1 == 150 * Math.pow(10,18)  / 1000 * 300, true,"sellReserve is wrong");
    });

    /// 出售10000fdt
    it("buy 30eth",async()=>{
        let amount = 10000;
        let amountOfFdToken_before = (await fdTokenIns.balanceOf(root))/1;
        let balanceOfRoot_before = await web3.eth.getBalance(root);
        let balanceOfTradeFundPool_before = (await web3.eth.getBalance(tradeFundPoolIns.address))/1;
        let totalSupply = (await fdTokenIns.totalSupply()) / 1;
        let sellReserve = await tradeFundPoolIns.sellReserve();
        assert.equal(sellReserve / 1 == 150 * Math.pow(10,18)  / 1000 * 300, true,"sellReserve is wrong");

        //出售10000个fdt
        await tradeFundPoolIns.sell(amount,{value:0,from:root});

        let balanceOfRoot_after = await web3.eth.getBalance(root);
        let balanceOfTradeFundPool_after = (await web3.eth.getBalance(tradeFundPoolIns.address))/1;
        let amountOfFdToken_after = (await fdTokenIns.balanceOf(root))/1;
        //检查出售的数额是否正确
        assert.equal(amountOfFdToken_after,amountOfFdToken_before - amount,"sell wrong");

        let value = sellReserve*amount*(2*totalSupply - amount)/totalSupply/totalSupply;
        //assert.equal(balanceOfRoot_after - balanceOfRoot_before <= value,"get eth is wrong");

        //检查融资模块里面的eth数额是否正确
        assert.equal(balanceOfTradeFundPool_before,balanceOfTradeFundPool_after+value,"balance of tradeFundPool is wrong");
    })

    it("revenue 50eth",async()=>{
        let _value = 50 * Math.pow(10,18);
        let totalSupply_before = (await fdTokenIns.totalSupply())/1;
        let balanceOfRoot_before = await web3.eth.getBalance(root);
        let balanceOfTradeFundPool_before = await web3.eth.getBalance(tradeFundPoolIns.address);

        await tradeFundPoolIns.revenue({value:_value});
        let totalSupply_after = (await fdTokenIns.totalSupply())/1;
        let balanceOfRoot_after = await web3.eth.getBalance(root);
        let balanceOfTradeFundPool_after = await web3.eth.getBalance(tradeFundPoolIns.address);

        assert.equal(totalSupply_before == totalSupply_after,true,"totalSupply is wrong");
        assert.equal(balanceOfRoot_before - balanceOfRoot_after < 51 * Math.pow(10,18),true,"balance of root is wrong");
        assert.equal(balanceOfTradeFundPool_after - balanceOfTradeFundPool_before == 50 * Math.pow(10,18),true,"balance of trade is wrong");
    });

    //token 转账
    it("token transfer",async()=>{
        let amount = 1000;
        let amountOfFdToken_Root_before = (await fdTokenIns.balanceOf(root))/1;
        let amountOfFdToken_User1_before = (await fdTokenIns.balanceOf(user1))/1;

        await fdTokenIns.transfer(user1,amount,{value:0,from:root});

        let amountOfFdToken_Root_after = (await fdTokenIns.balanceOf(root))/1;
        let amountOfFdToken_User1_after = (await fdTokenIns.balanceOf(user1))/1;

        assert.equal(amountOfFdToken_Root_before - amountOfFdToken_Root_after == amount,true,"amount of root is wrong");
        assert.equal(amountOfFdToken_User1_after - amountOfFdToken_User1_before == amount,true,"amount of user1 is wrong");
    });

    //token approve
    it("token approve",async()=>{
        let amount = 10000;
        let amountOfFdToken_Root_before = (await fdTokenIns.balanceOf(root))/1;
        let amountOfFdToken_User1_before = (await fdTokenIns.balanceOf(user1))/1;

        await fdTokenIns.approve(user1,amount,{value:0,from:root});

        let amount2 = await fdTokenIns.allowance(root,user1,{value:0,from:root});
        assert.equal(amount2 == amount,true,"approve faild");

        let amountOfFdToken_Root_after = (await fdTokenIns.balanceOf(root))/1;
        let amountOfFdToken_User1_after = (await fdTokenIns.balanceOf(user1))/1;

        assert.equal(amountOfFdToken_Root_before == amountOfFdToken_Root_after,true,"amount of root is wrong");
        assert.equal(amountOfFdToken_User1_after == amountOfFdToken_User1_before,true,"amount of user1 is wrong");
    });

    //approve 之后由user1 给user2转8888
    //token 转账
    it("token transferFrom  user1 to user2",async()=>{
        let amount = 8888;
        let amountOfFdToken_Root_before = (await fdTokenIns.balanceOf(root))/1;
        let amountOfFdToken_User1_before = (await fdTokenIns.balanceOf(user1))/1;
        let amountOfFdToken_User2_before = (await fdTokenIns.balanceOf(user2))/1;
        let allowance_root_user1_before = await fdTokenIns.allowance(root,user1,{value:0,from:root});

        await fdTokenIns.transferFrom(root,user2,amount,{value:0,from:user1});

        let allowance_root_user1_after = await fdTokenIns.allowance(root,user1,{value:0,from:root});
        let amountOfFdToken_Root_after = (await fdTokenIns.balanceOf(root))/1;
        let amountOfFdToken_User1_after = (await fdTokenIns.balanceOf(user1))/1;
        let amountOfFdToken_User2_after = (await fdTokenIns.balanceOf(user2))/1;

        assert.equal(amountOfFdToken_Root_before - amountOfFdToken_Root_after == amount,true,"amount of root is wrong");
        assert.equal(amountOfFdToken_User1_after == amountOfFdToken_User1_before,true,"amount of user1 is wrong");
        assert.equal(amountOfFdToken_User2_after - amountOfFdToken_User2_before == amount,true,"amount of user1 is wrong");
        assert.equal(allowance_root_user1_before - allowance_root_user1_after == amount,true,"allowance_root_user1 is wrong");
    });


    ///////////////////////
    //// 下面是测试 自治部分的逻辑
    //////////////////////

    // appManager 和 fdtoken 合约地址是否正确
    it("appManager set correct in GovernShareManager",async()=>{
        let _appManagerInGovernShareManager = await governShareManagerIns.getAppManagerAddress();
        assert.equal(_appManagerInGovernShareManager == appManagerIns.address,true,"appManager set correct in governShareManager wrong");
    });

    it("fdToken set correct in GovernShareManager",async()=>{
        let _tokenInGovernShareManager = await governShareManagerIns.token();
        assert.equal(_tokenInGovernShareManager == fdTokenIns.address,true,"fdToken set correct in governShareManager wrong");

        let _supplyFromGovern = (await governShareManagerIns.getFdtTotalSupply()) / 1;
        let _supplyFromToken = (await fdTokenIns.totalSupply()) / 1;
        assert.equal(_supplyFromGovern == _supplyFromToken,true,"fdToken set correct in governShareManager wrong  ----2");
    });

    it("appManager set correct in voteApplyFund",async()=>{
        let _appManagerInVoteApplyFund = await vote_ApplyFundIns.getAppManagerAddress();
        assert.equal(_appManagerInVoteApplyFund == appManagerIns.address,true,"appManager set correct in VoteApplyFund wrong");
    });

    /// 把股份币转进自治模块
    it("set fdt in",async()=>{
        let amount = 1000;
        let _balanceInFdt_before = (await fdTokenIns.balanceOf(root)) / 1;
        let _balanceInGovern_before = (await governShareManagerIns.getFdtInGovern(root)) / 1;
        await fdTokenIns.approve(governShareManagerIns.address,amount);
        await governShareManagerIns.setFdtIn(amount);
        let _balanceInFdt_after = (await fdTokenIns.balanceOf(root)) / 1;
        let _balanceInGovern_after = (await governShareManagerIns.getFdtInGovern(root)) / 1;
        console.log(`FDT   before:${_balanceInFdt_before} after:${_balanceInFdt_after}`);
        console.log(`Govern   before:${_balanceInGovern_before} after:${_balanceInGovern_after}`);
        assert.equal(_balanceInFdt_before == _balanceInFdt_after + amount,true,"set fdt in faild");
        assert.equal(_balanceInGovern_after == _balanceInGovern_before + amount,true,"set fdt in faild");
    })

    /// 提取股份币
    it("get fdt out",async()=>{
        let amount = 100;
        let _balanceInFdt_before = (await fdTokenIns.balanceOf(root)) / 1;
        let _balanceInGovern_before = (await governShareManagerIns.getFdtInGovern(root)) / 1;
        await governShareManagerIns.getFdtOut(amount);
        let _balanceInFdt_after = (await fdTokenIns.balanceOf(root)) / 1;
        let _balanceInGovern_after = (await governShareManagerIns.getFdtInGovern(root)) / 1;
        console.log(`FDT   before:${_balanceInFdt_before} after:${_balanceInFdt_after}`);
        console.log(`Govern   before:${_balanceInGovern_before} after:${_balanceInGovern_after}`);

        assert.equal(_balanceInFdt_before == _balanceInFdt_after - amount,true,"set fdt in faild");
        assert.equal(_balanceInGovern_after == _balanceInGovern_before - amount,true,"set fdt in faild");
    });


    /// 发起一个转账提议
    it("apply Proposal",async()=>{
        let _count1 =(await vote_ApplyFundIns.getProposalQueueLength()) / 1;
        assert.equal(_count1 == 0,true,"count is wrong --1");

        await vote_ApplyFundIns.applyProposal("p1",user1,1 * (10 ** 15),0,"就是为了测试",0,{from:root,value:1.1 * Math.pow(10,18)});

        let _count2 =(await vote_ApplyFundIns.getProposalQueueLength())/1;
        assert.equal(_count2 == _count1 + 1,true,"count is wrong --2");

        let amountOfProposalToday = (await vote_ApplyFundIns.getAmountOfProposalToday())/1;
        assert.equal(amountOfProposalToday == 1,true,"amountOfProposalToday is wrong");

        ///接下来比对信息
        let baseInfo = await vote_ApplyFundIns.getProposalBaseInfoByIndex(1);
        let _proposalName = baseInfo[0];
        let _proposer = baseInfo[1];
        let _detail = baseInfo[2];
        let _address_tap = baseInfo[3];
        let _retrialIndex = baseInfo[4];
        console.log(`_address_tap:${_address_tap}`);
        assert.equal(_proposalName == "p1",true,"_proposalName is wrong");
        assert.equal(_proposer == root,true,"_proposer is wrong");
        assert.equal(_detail == "就是为了测试",true,"_detail is wrong");
        assert.equal(_retrialIndex == 0,true,"_retrialIndex is wrong");

        let state = await vote_ApplyFundIns.getProposalStateByIndex(1);
        let _approveVotes = state[0];
        let _refuseVotes = state[1];
        let _process = state[2];
        let _pass = state[3];
        let _abort = state[4];
        let _abandon = state[5];
        let _oneTicketRefuse = state[6];
        assert.equal(_approveVotes == 0,true,"_approveVotes is wrong");
        assert.equal(_refuseVotes == 0,true,"_refuseVotes is wrong");
        assert.equal(_process == false,true,"_process is wrong");
        assert.equal(_pass == false,true,"_pass is wrong");
        assert.equal(_abort == false,true,"_abort is wrong");
        assert.equal(_abandon == false,true,"_abandon is wrong");
        assert.equal(_oneTicketRefuse == false,true,"_oneTicketRefuse is wrong");

        let tap = await vote_ApplyFundIns.getProposalTapByIndex(1);
        let _startTime = tap[0];
        let _recipient = tap[1];
        let _value = tap[2];
        let _timeConsuming = tap[3];

        assert.equal(_recipient == user1,true," _recipient is wrong");
        assert.equal(_value == 1 * (10 ** 15),true,"_value is wrong");
        assert.equal(_timeConsuming == 0,true,"_timeConsuming is wrong");
    });
/*
    /// 终止提议
    it("abort",async()=>{
        await Ut.sleep(10000);//等待10s
        console.log("开始终止提议");
        await vote_ApplyFundIns.abortProposal(1);
        let state = await vote_ApplyFundIns.getProposalStateByIndex(1);
        let _approveVotes = state[0];
        let _refuseVotes = state[1];
        let _process = state[2];
        let _pass = state[3];
        let _abort = state[4];
        let _abandon = state[5];
        let _oneTicketRefuse = state[6];

        assert.equal(_approveVotes == 0,true,"_approveVotes is wrong");
        assert.equal(_refuseVotes == 0,true,"_refuseVotes is wrong");
        assert.equal(_process == false,true,"_process is wrong");
        assert.equal(_pass == false,true,"_pass is wrong");
        assert.equal(_abort == true,true,"_abort is wrong");
        assert.equal(_abandon == false,true,"_abandon is wrong");
        assert.equal(_oneTicketRefuse == false,true,"_oneTicketRefuse is wrong");

        let amountOfProposalToday = (await vote_ApplyFundIns.getAmountOfProposalToday())/1;
        assert.equal(amountOfProposalToday == 0,true,"amountOfProposalToday is wrong");
    });
*/

    /// 一票否决了
    it("oneTicketRefuse",async()=>{
        await Ut.sleep(10000);//等待10s
        console.log("准备一票否决了");
        await vote_ApplyFundIns.oneTicketRefuseProposal(1);
        let state = await vote_ApplyFundIns.getProposalStateByIndex(1);
        let _approveVotes = state[0];
        let _refuseVotes = state[1];
        let _process = state[2];
        let _pass = state[3];
        let _abort = state[4];
        let _abandon = state[5];
        let _oneTicketRefuse = state[6];
        assert.equal(_approveVotes == 0,true,"_approveVotes is wrong");
        assert.equal(_refuseVotes == 0,true,"_refuseVotes is wrong");
        assert.equal(_process == false,true,"_process is wrong");
        assert.equal(_pass == false,true,"_pass is wrong");
        assert.equal(_abort == false,true,"_abort is wrong");
        assert.equal(_abandon == false,true,"_abandon is wrong");
        assert.equal(_oneTicketRefuse == true,true,"_oneTicketRefuse is wrong");

        let amountOfProposalToday = (await vote_ApplyFundIns.getAmountOfProposalToday())/1;
        assert.equal(amountOfProposalToday == 0,true,"amountOfProposalToday is wrong");
    });
    
    /// 投票
    it("vote",async()=>{

        await Ut.sleep(20000); // 等待20s再发起提案
        console.log("开始投票");

        let amount = 888;
        let _balanceInGovern_before = (await governShareManagerIns.getFdtInGovern(root)) / 1;
        //console.log(_balanceInGovern_before);
        await vote_ApplyFundIns.vote(1,1,amount);
        let _balanceInGovern_after = (await governShareManagerIns.getFdtInGovern(root)) / 1;
        //console.log(_balanceInGovern_after);

        ///比对数据
        //投票的数量是否正确
        assert.equal(_balanceInGovern_before-_balanceInGovern_after == amount,true,"vote shares is wrong");
        //比对提议中记录的数据
        let state = await vote_ApplyFundIns.getProposalStateByIndex(1);
        let _approveVotes = state[0];
        let _refuseVotes = state[1];
        let _process = state[2];
        let _pass = state[3];
        let _abort = state[4];
        let _abandon = state[5];
        let _oneTicketRefuse = state[6];
        assert.equal(_approveVotes == amount,true,"_approveVotes is wrong");
        assert.equal(_refuseVotes == 0,true,"_refuseVotes is wrong");
        assert.equal(_process == false,true,"_process is wrong");
        assert.equal(_pass == false,true,"_pass is wrong");
        assert.equal(_abort == false,true,"_abort is wrong");
        assert.equal(_abandon == false,true,"_abandon is wrong");
        assert.equal(_oneTicketRefuse == false,true,"_oneTicketRefuse is wrong");
    });

    ///
});


