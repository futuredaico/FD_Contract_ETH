const AppManager = artifacts.require("AppManager");
const Co = artifacts.require("Co");
const SharesB = artifacts.require("SharesB");
const TradeFundPool = artifacts.require("TradeFundPool");
const DateTime = artifacts.require("DateTime");
const Dai = artifacts.require("Dai");

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

    let user3 = accounts[3]; //暂时用这个地址当做moloch的地址

    let mintDaiAmount = 10000 * Math.pow(10,8);

    let tradeFundPoolIns , sharesBIns , appManagerIns , coIns , DateTimeIns ,DaiIns;
    let bytes32_EMPTY_PARAM_HASH , bytes32_FundPool_Start , bytes32_SharesB_Burn , bytes32_SharesB_Mint;

    it("init",async()=>{
        tradeFundPoolIns = await TradeFundPool.deployed();
        sharesBIns = await SharesB.deployed();
        appManagerIns = await AppManager.deployed();
        coIns = await Co.deployed();
        DateTimeIns = await DateTime.deployed();
        DaiIns = await Dai.deployed();
        
        bytes32_EMPTY_PARAM_HASH = await tradeFundPoolIns.EMPTY_PARAM_HASH();
        bytes32_FundPool_Start = await tradeFundPoolIns.FundPool_Start();
        bytes32_FundPool_ChangeRatio = await tradeFundPoolIns.FundPool_ChangeRatio();
        bytes32_SharesB_Burn = await sharesBIns.SharesB_Burn();
        bytes32_SharesB_Mint = await sharesBIns.SharesB_Mint();
        

        await appManagerIns.initialize(tradeFundPoolIns.address,user3,DateTimeIns.address);
    
        ///分配权限
        await appManagerIns.addPermission(root,tradeFundPoolIns.address,bytes32_FundPool_Start);
        await appManagerIns.addPermission(tradeFundPoolIns.address,sharesBIns.address,bytes32_SharesB_Burn);
        await appManagerIns.addPermission(tradeFundPoolIns.address,sharesBIns.address,bytes32_SharesB_Mint);
    });

    //////////////////////////DAI
    it("check dai params",async()=>{
      let _name = await DaiIns.name();
      let _decimals = await DaiIns.decimals();
      let _symbol = await DaiIns.symbol();
      assert.equal(_name == "DAI",true,"_name is wrong");
      assert.equal(_decimals == 8,true,"_decimals is wrong");
      assert.equal(_symbol == "dai",true,"_symbol is wrong");
    });

    it("mint dai",async()=>{
      let _balance = await DaiIns.balanceOf(root);
      let _totalSupply = await DaiIns.totalSupply();
      assert.equal(_balance == 0,true,"_balance is wrong");
      assert.equal(_totalSupply == 0,true,"_totalSupply is wrong");

      await DaiIns.mint(root,mintDaiAmount,{from:root});

      _balance = await DaiIns.balanceOf(root);
      _totalSupply = await DaiIns.totalSupply();
      assert.equal(_balance == mintDaiAmount,true,"_balance is wrong");
      assert.equal(_totalSupply == mintDaiAmount,true,"_totalSupply is wrong");
    });

    ////////////////////////////trade
    it("check trade params monthlyAllocationRatio_1000",async()=>{
        let _monthlyAllocationRatio_1000 =await tradeFundPoolIns.monthlyAllocationRatio_1000();
        assert.equal(_monthlyAllocationRatio_1000 == 50,true,"_monthlyAllocationRatio_1000 is wrong");
    });

    it("check trade is start",async()=>{
        let _started = await tradeFundPoolIns.started();
        assert.equal(_started == false,true,"started is wrong");
    });

    it("start trade",async()=>{
        await tradeFundPoolIns.start();
        let _started = await tradeFundPoolIns.started();
        assert.equal(_started == true,true,"started is wrong");
    });

    // it("changeRatio ---  need falild",async()=>{
    //     await tradeFundPoolIns.changeRatio(60);
    //     let _monthlyAllocationRatio_1000 = await tradeFundPoolIns.monthlyAllocationRatio_1000();
    //     assert.equal(_monthlyAllocationRatio_1000 == 60,true,"_monthlyAllocationRatio_1000 is wrong");
    // });

    it("changeRatio --- need success",async()=>{
      //先赋予权限
      await appManagerIns.addPermission(root,tradeFundPoolIns.address,bytes32_FundPool_ChangeRatio);

      await tradeFundPoolIns.changeRatio(60);
      let _monthlyAllocationRatio_1000 = await tradeFundPoolIns.monthlyAllocationRatio_1000();
      assert.equal(_monthlyAllocationRatio_1000 == 60,true,"_monthlyAllocationRatio_1000 is wrong");
    });

    it("buy",async()=>{
      //运行合约使用我dai中的钱
      await DaiIns.approve(tradeFundPoolIns.address,100000000);
      let allowance =await DaiIns.allowance(root,tradeFundPoolIns.address);
      console.log(allowance);
      assert.equal(allowance == 100000000,true,"approve is wrong");
      
      let balance = await sharesBIns.balanceOf(root);
      assert.equal(balance == 0,true,"balance is wrong");
      await tradeFundPoolIns.buy(100000000,0,"aaaaaaaaaaaa");
      balance = await sharesBIns.balanceOf(root);
      console.log(balance);
      assert.equal(balance == 141,true,"balance is wrong");
    })
});


