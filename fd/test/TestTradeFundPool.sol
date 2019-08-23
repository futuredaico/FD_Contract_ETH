pragma solidity >=0.4.22 <0.6.0;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/TradeFundPool.sol";

contract TestTradeFundPool {
    uint public initialBalance = 150 ether;
    event test (bool b);

    struct M{
    //参数缓存一份记录在本合约只为读取方便
    uint256 fundPoolCrowdFundMoney; //fundpool 合约众筹目标
    uint256 fundPoolCrowdPrice; //众筹时候的价格
    uint256 crowdFundDuringTime;//fundPool 众筹的时间
    uint256 slope;//曲线增长的斜率 乘以了1000以提高精度
    uint256 alpha; //储备池分成的比例   乘以了1000
    uint256 beta; //项目盈利回购分给储备池的比例 乘以了1000
    uint256 balance_eth_fundPool;//fundpool 以太坊的余额
    uint256 balance_eth_vote;//vote合约以太坊的余额
    uint256 balance_eth_this;//本合约的以太坊余额
    uint256 balance_fnd_this;//本合约的fnd的余额
    uint256 balance_fnd_origin;//origin的fnd的余额
    uint256 totalSupply;//fundpool合约一共发行了多少的fnd
    uint256 preSupply;//fundPool合约预挖了多少fnd
    uint256 sellReserve;//fundpool合约储备池中的钱
    uint256 totalSendToVote;//fundPool合约中发给自治的钱
    bool during_crowdfunding;//fundPool合约中发给自治的钱
    }

    mapping(string=>M) map;

    function() external payable{
    }

    /// @notice 开根号的计算方法
    /// @param x 要开根的数
    /// @return 开根之后的数
    function sqrt(uint256 x) private pure returns(uint256){
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while(z < y){
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }

    /// @notice 更新缓存的数据
    function refreshParams(string memory s) private{
        TradeFundPool tradeFundPoolIns = TradeFundPool(DeployedAddresses.TradeFundPool());
        GovernFundPool governFundPoolIns = GovernFundPool(DeployedAddresses.GovernFundPool());
        M memory m = M({
        fundPoolCrowdFundMoney : tradeFundPoolIns.crowdFundMoney(),
        fundPoolCrowdPrice : tradeFundPoolIns.crowdFundPrice(),
        slope : tradeFundPoolIns.slope(),
        alpha : tradeFundPoolIns.alpha(),
        beta : tradeFundPoolIns.beta(),
        crowdFundDuringTime : tradeFundPoolIns.crowdFundDuringTime(),
        totalSupply : tradeFundPoolIns.totalSupply(),
        preSupply : tradeFundPoolIns.preSupply(),
        balance_fnd_this : tradeFundPoolIns.getBalance(address(this)),
        balance_fnd_origin : tradeFundPoolIns.getBalance(address(tx.origin)),
        balance_eth_this : address(this).balance,
        balance_eth_vote : address(governFundPoolIns).balance,
        balance_eth_fundPool : address(tradeFundPoolIns).balance,
        sellReserve : tradeFundPoolIns.sellReserve(),
        totalSendToVote : tradeFundPoolIns.totalSendToVote(),
        during_crowdfunding : tradeFundPoolIns.during_crowdfunding()
        });
        map[s] = m;
    }


    /// @notice 出于权限问题，重新设置fundpool的owner。
    function testReinstallOwner() public{
        TradeFundPool tradeFundPoolIns = TradeFundPool(DeployedAddresses.TradeFundPool());
        bool r = tradeFundPoolIns.reinstallOwner(address(this));
        Assert.equal(r,true,"reinstall owner failed");
    }

    /// @notice 设置vote合约
    function testSetVote() public{
        TradeFundPool tradeFundPoolIns = TradeFundPool(DeployedAddresses.TradeFundPool());
        GovernFundPool GovernFundPoolIns = GovernFundPool(DeployedAddresses.GovernFundPool());
        bool r;
        (r,) = address(tradeFundPoolIns).call(abi.encodeWithSignature("unsafe_setGovernFundPool(address)",address(GovernFundPoolIns)));
        Assert.equal(r,true,"first set govern failed");

        (r,) = address(tradeFundPoolIns).call(abi.encodeWithSignature("unsafe_setGovernFundPool(address)",address(GovernFundPoolIns)));
        Assert.isFalse(r,"fundpool cant set govern again");

        address voteAddr = tradeFundPoolIns.getGovernFundPoolAddress();
        Assert.equal(address(GovernFundPoolIns),voteAddr,"govern contract is wrong");
    }

    /// @notice 设置斜率
    function testSetSlope() public{
        TradeFundPool tradeFundPoolIns = TradeFundPool(DeployedAddresses.TradeFundPool());
        uint256 _slope = 10 ** 12;
        tradeFundPoolIns.setSlope(_slope);
        Assert.equal(tradeFundPoolIns.slope(),_slope,"set slope failed");
    }

    /// @notice 设置储备分钱的比例
    function testSetAlpha() public{
        TradeFundPool tradeFundPoolIns = TradeFundPool(DeployedAddresses.TradeFundPool());
        uint256 _alpha = 300;
        tradeFundPoolIns.setAlpha(_alpha);
        Assert.equal(tradeFundPoolIns.alpha(),_alpha,"set alpha failed");
    }

    /// @notice 设置回购储备分钱的比例
    function testSetBeta() public{
        TradeFundPool tradeFundPoolIns = TradeFundPool(DeployedAddresses.TradeFundPool());
        uint256 _beta = 800;
        tradeFundPoolIns.setBeta(_beta);
        Assert.equal(tradeFundPoolIns.beta(),_beta,"set beta failed");
    }

    /// @notice 验证合约参数
    function testPrarams() public{
        refreshParams("params_1");
        M memory m = map["params_1"];
        Assert.equal(m.crowdFundDuringTime,30*24*60*60,"d is worng");
        Assert.equal(m.fundPoolCrowdFundMoney,10**20,"m is worng");
        Assert.equal(m.slope,1000 * 10**9,"s is worng");
        Assert.equal(m.alpha,300,"a is worng");
        Assert.equal(m.beta,800,"b is worng");
        Assert.equal(m.fundPoolCrowdPrice,223606000000000,"p is worng");
    }

    /// @notice 预发售股份
    function testPreMint() public{
        TradeFundPool tradeFundPoolIns = TradeFundPool(DeployedAddresses.TradeFundPool());
        bool r;
        (r,) =address(tradeFundPoolIns).call(abi.encodeWithSignature("preMint(address,uint256)",tx.origin,100));
        Assert.equal(r,true,"need true");

        uint256 balance = tradeFundPoolIns.getBalance(tx.origin);
        Assert.equal(balance,100,"fnd amount is wrong");
    }

    /// @notice 没有开始的时候 合约某些方法是禁止调用的
    function testSomeFuncWhenNoBeginning() public{
        TradeFundPool tradeFundPoolIns = TradeFundPool(DeployedAddresses.TradeFundPool());
        bool r;
        (r,) = address(tradeFundPoolIns).call.value(10000)(abi.encodeWithSignature("crowdfunding(bool)",false));
        Assert.isFalse(r,"need false");

        (r,) = address(tradeFundPoolIns).call(abi.encodeWithSignature("windingUp()"));
        Assert.isFalse(r,"need false");

        (r,) = address(tradeFundPoolIns).call.value(100000)(abi.encodeWithSignature("buy()"));
        Assert.isFalse(r,"need false");

        (r,) = address(tradeFundPoolIns).call(abi.encodeWithSignature("sell(uint256)",10));
        Assert.isFalse(r,"need false");

        (r,) = address(tradeFundPoolIns).call(abi.encodeWithSignature("transfer(address,uint256)",address(tradeFundPoolIns),10));
        Assert.isFalse(r,"need false");

        (r,) = address(tradeFundPoolIns).call.value(100000)(abi.encodeWithSignature("revenue()"));
        Assert.isFalse(r,"need false");
    }

    /// @notice 开始
    function testStart() public{
        TradeFundPool tradeFundPoolIns = TradeFundPool(DeployedAddresses.TradeFundPool());

        bool b = tradeFundPoolIns.started();
        Assert.equal(b,false,"It shouldn't have started yet");

        tradeFundPoolIns.start();

        b = tradeFundPoolIns.started();
        Assert.equal(b,true,"It should have started yet");
    }

    /// @notice 参与众筹  先加个50eth
    function testCrowdfunding() public payable{
        ///先存50eth , 7 3分成的话  储备池15 自治池35
        uint256 value = 50 ether;

        TradeFundPool tradeFundPoolIns = TradeFundPool(DeployedAddresses.TradeFundPool());

        //发送前参数情况
        refreshParams("c1_1");
        M memory m1 = map["c1_1"];

        //验证还在众筹期
        Assert.equal(m1.during_crowdfunding,true,"during_crowdfunding need true");

        //验证众筹后各个参数的情况
        (bool r,) = address(tradeFundPoolIns).call.value(value)(abi.encodeWithSignature("crowdfunding(bool)",false));
        Assert.equal(r,true,"crowdfunding failed");

        //50eth可以购买到的fnd的数量  //223607
        uint256 amount = 50 ether / m1.fundPoolCrowdPrice;

        //发送后参数情况
        refreshParams("c1_2");
        M memory m2 = map["c1_2"];

        Assert.equal(m2.balance_eth_fundPool,value,"fundpool balance wrong"); //fund合约应该有50eth的余额
        Assert.equal(m2.balance_eth_vote,0,"govern balance wrong");//vote合约内应该没有eth
        Assert.equal(m2.sellReserve,value * 300,"sellReserve is wrong");//储备池记录的数额应该是15eth
        Assert.equal(m2.totalSendToVote,value * 700,"totalSendToVote is wrong");//自治池记录的数额应该是35eth
        Assert.equal(m2.balance_fnd_this,amount+m1.balance_fnd_this,"fnd amount is wrong");//验证fnd的数量对不对
        Assert.equal(m2.totalSupply, amount + m1.totalSupply,"totalSupply is wrong");//验证fnd发行总量对不对

        //发起交易后 用了50eth
        Assert.equal(m2.balance_eth_this,m1.balance_eth_this - value,"sender value is wrong");

        //应该还在众筹期
        Assert.equal(m2.during_crowdfunding,true,"during_crowdfunding need true");
    }
/*
    /// @notice 参与众筹 再加50eth 使目标刚好达成
    function _testCrowdfunding2() public payable{
        uint256 value = 50 ether;
        TradeFundPool tradeFundPoolIns = TradeFundPool(DeployedAddresses.TradeFundPool());

        //发送前参数情况
        refreshParams("c2_1");
        M memory m1 = map["c2_1"];

        //验证还在众筹期
        Assert.equal(m1.during_crowdfunding,true,"during_crowdfunding need true");

        //验证刚好达成目标的情况下，各个参数是否正常
        (bool r,) = address(tradeFundPoolIns).call.value(value)(abi.encodeWithSignature("crowdfunding(bool)",false));
        Assert.equal(r,true,"crowdfunding failed");

        //发送后参数情况
        refreshParams("c2_2");
        M memory m2 = map["c2_2"];

        //50eth可以购买到的fnd的数量  //223607
        uint256 amount = 50 ether / m1.fundPoolCrowdPrice;

        Assert.equal(m2.sellReserve,m1.fundPoolCrowdFundMoney * m1.alpha,"sellReserve is wrong");//储备合约中应该有30eth
        Assert.equal(m2.totalSendToVote,m1.fundPoolCrowdFundMoney * (1000 - m1.alpha),"totalSendToVote is wrong");//自治合约中应该有70eth
        Assert.equal(m2.balance_eth_vote,70 ether,"govern balance wrong");//自治池中应该有70eth
        Assert.equal(m2.balance_eth_fundPool,30 ether,"fundPool balance wrong");//储备池中应该有30eth
        Assert.equal(m2.balance_fnd_this,m1.balance_fnd_this+amount,"fnd amount is wrong");//验证该地址拥有的fnd的数量是否正确
        Assert.equal(m2.totalSupply,m1.totalSupply+amount,"totalSupply is wrong");

        //发起交易后 用了50
        Assert.equal(m2.balance_eth_this,m1.balance_eth_this - value,"sender value is wrong");

        //这里众筹应该结束了，参数状态要改成false
        Assert.equal(m2.during_crowdfunding,false,"during_crowdfunding need false");
    }

    /// @notice 参与众筹 再加70eth 超过部分要求退回
    function _testCrowdfunding3() public payable{
        uint256 value = 70 ether;

        TradeFundPool tradeFundPoolIns = TradeFundPool(DeployedAddresses.TradeFundPool());

        //没有发送交易前合约的参数情况
        refreshParams("c3_1");
        M memory m1 = map["c3_1"];

        //验证还在众筹期
        Assert.equal(m1.during_crowdfunding,true,"during_crowdfunding need true");

        //验证刚好达成目标的情况下，各个参数是否正常
        (bool r,) = address(tradeFundPoolIns).call.value(value)(abi.encodeWithSignature("crowdfunding(bool)",true));
        Assert.equal(r,true,"crowdfunding failed");

        //发送后参数情况
        refreshParams("c3_2");
        M memory m2 = map["c3_2"];

        //50eth可以购买到的fnd的数量  //223607
        uint256 amount = 50 ether / m1.fundPoolCrowdPrice;

        Assert.equal(m2.sellReserve,m1.fundPoolCrowdFundMoney * m1.alpha,"sellReserve is wrong");//储备合约中应该有30eth
        Assert.equal(m2.totalSendToVote,m1.fundPoolCrowdFundMoney * (1000 - m1.alpha),"totalSendToVote is wrong");//自治合约中应该有70eth
        Assert.equal(m2.balance_eth_vote,70 ether,"govern balance wrong");//自治池中应该有70eth
        Assert.equal(m2.balance_eth_fundPool,30 ether,"fundPool balance wrong");//储备池中应该有30eth
        Assert.equal(m2.balance_fnd_this,m1.balance_fnd_this+amount,"fnd amount is wrong");//验证该地址拥有的fnd的数量是否正确
        Assert.equal(m2.totalSupply,m1.totalSupply+amount,"totalSupply is wrong");

        //发起交易后 用了70 退了20 应该只花了50
        Assert.equal(m2.balance_eth_this,m1.balance_eth_this - value + 20 ether,"sender value is wrong");

        //这里众筹应该结束了，参数状态要改成false
        Assert.equal(m2.during_crowdfunding,false,"during_crowdfunding need false");
    }
*/
    /// @notice 参与众筹 继50eth之后再加70eth 超过部分不要求退还
    function testCrowdfunding4() public payable{
        uint256 value = 70 ether;
        TradeFundPool tradeFundPoolIns = TradeFundPool(DeployedAddresses.TradeFundPool());

        //记录发交易之前的参数情况
        refreshParams("c4_1");
        M memory m1 = map["c4_1"];

        //验证还在众筹期
        Assert.equal(m1.during_crowdfunding,true,"during_crowdfunding need true");

        //验证各个参数是否正常
        (bool r,) = address(tradeFundPoolIns).call.value(value)(abi.encodeWithSignature("crowdfunding(bool)",false));
        Assert.equal(r,true,"crowdfunding failed");

        //70eth中50eth可以购买到的fnd的数量  //223607
        uint256 amount1 = 50 ether / m1.fundPoolCrowdPrice;
        //Assert.equal(amount1,223607,"amount1 is wrong");
        //剩余20eth根据曲线可以购买得到的量  //42775
        //Assert.equal(m1.slope,1000000000000,"m1.slope is wrong");
        //Assert.equal(m1.totalSupply,223707,"m1.totalSupply is wrong");
        uint256 curTotal = (m1.totalSupply+amount1);
        //Assert.equal(curTotal,447314,"curTotal is wrong");
        uint256 amount2 = sqrt(2 * 20 ether * 1000 / m1.slope + curTotal * curTotal) - curTotal;
        //Assert.equal(amount2,42675,"amount2 is wrong");

        uint256 balance = amount1 + amount2 + m1.balance_fnd_this; //489989
        uint256 total = amount1 + amount2 + m1.totalSupply;

        refreshParams("c4_2");
        M memory m2 = map["c4_2"];

        Assert.equal(m2.sellReserve,(value + 50 ether) * m1.alpha,"sellReserve is wrong");//储备合约中应该有36eth
        Assert.equal(m2.totalSendToVote,(value + 50 ether) * (1000 - m1.alpha),"totalSendToVote is wrong");//自治合约中应该有84eth
        Assert.equal(m2.balance_eth_vote,(value + 50 ether) * (1000 - m1.alpha) / 1000,"govern balance wrong");//自治池中应该有84eth
        Assert.equal(m2.balance_eth_fundPool,(value + 50 ether) * m1.alpha / 1000,"fundPool balance wrong");//储备池中应该有36eth
        Assert.equal(m2.balance_fnd_this,balance,"fnd amount is wrong");//验证该地址拥有的fnd的数量是否正确
        Assert.equal(m2.totalSupply,total,"totalSupply is wrong");

        //发起交易后 用了70
        Assert.equal(m2.balance_eth_this,m1.balance_eth_this - value,"sender value is wrong");

        //这里众筹应该结束了，参数状态要改成false
        Assert.equal(m2.during_crowdfunding,false,"during_crowdfunding need false");
    }


    /// @notice 此时众筹结束了 可以按照曲线正常购买  购买个0.5eth试试
    function testBuy() public payable{
        uint256 value = 0.5 ether;
        TradeFundPool tradeFundPoolIns = TradeFundPool(DeployedAddresses.TradeFundPool());

        //先记录合约当前的一些参数
        refreshParams("buy_1");
        M memory m1 = map["buy_1"];

        //买起来
        (bool r,) = address(tradeFundPoolIns).call.value(value)(abi.encodeWithSignature("buy()"));
        Assert.equal(r,true,"buy failed");

        //事先预算 用value的值可以购买多少的fnd
        uint256 _fndAmount = sqrt(2 * value * 1000 / m1.slope + m1.totalSupply * m1.totalSupply) - m1.totalSupply;

        //发送交易之后合约的参数状况
        refreshParams("buy_2");
        M memory m2 = map["buy_2"];

        Assert.equal(m2.balance_fnd_this,m1.balance_fnd_this + _fndAmount,"buy fnd amount is wrong");//fnd的数量
        Assert.equal(m2.totalSupply,m1.totalSupply + _fndAmount,"totalSupply is wrong");//totalSupply
        Assert.equal(m2.sellReserve,m1.sellReserve + value * m1.alpha,"sellReserve is wrong "); //sellReserve
        Assert.equal(m2.totalSendToVote,m1.totalSendToVote + value * (1000 - m1.alpha),"sellReserve is wrong "); //sendtoVote
        Assert.equal(m2.balance_eth_vote,m1.balance_eth_vote + value * (1000 - m1.alpha) / 1000,"balance of govern is wrong");
        Assert.equal(m2.balance_eth_fundPool,m1.balance_eth_fundPool + value * m1.alpha / 1000,"balance of fund is wrong");

        //用了0.5eth
        Assert.equal(m2.balance_eth_this,m1.balance_eth_this - value,"sender value is wrong");
    }

    /// @notice 卖点fnd试试水
    function testSell() public payable{
        uint256 amount = 100;
        TradeFundPool tradeFundPoolIns = TradeFundPool(DeployedAddresses.TradeFundPool());

        //先记录合约当前的一些参数
        refreshParams("sell_1");
        M memory m1 = map["sell_1"];

        //卖
        (bool r,) = address(tradeFundPoolIns).call(abi.encodeWithSignature("sell(uint256)",amount));
        Assert.equal(r,true,"sell failed");

        Assert.equal(m1.sellReserve,36.15 ether * 1000,"sellReserve is wrong");
        Assert.equal(m1.totalSupply,491008,"totalSupply is wrong");
        //预算能卖到多少钱
        uint256 value = m1.sellReserve * amount * (2 * m1.totalSupply - amount) / m1.totalSupply / m1.totalSupply;
        //Assert.equal(value,14723311553884962897,"value is wrong");

        //发送交易之后合约的参数状况
        refreshParams("sell_2");
        M memory m2 = map["sell_2"];

        Assert.equal(m2.balance_fnd_this,m1.balance_fnd_this - amount,"amount is wrong"); //拥有的fnd的数量应该减少了
        Assert.equal(m2.balance_eth_this,m1.balance_eth_this + value / 1000,"balance of this is wrong");//eth的数量增加了
        Assert.equal(m2.balance_eth_vote,m1.balance_eth_vote,"balance of govern is wrong");//vote合约的钱没有涉及到 应该保持不变
        Assert.equal(m2.balance_eth_fundPool,m1.balance_eth_fundPool - value / 1000,"balance of fundPool is wrong");//fundpool合约内的钱应该减少了
        Assert.equal(m2.sellReserve,m1.sellReserve - value,"sellReserve is wrong");//存储池中的钱应该减少了
        Assert.equal(m2.totalSendToVote,m1.totalSendToVote,"sendToVote is wrong");//总体发给自治部分的钱应该没有变化
    }
/*
    /// @notice 再买一点试试
    function testBuy2() public payable{
        uint256 value = 0.125 ether;
        TradeFundPool tradeFundPoolIns = TradeFundPool(DeployedAddresses.TradeFundPool());

        //先记录合约当前的一些参数
        refreshParams("buy2_1");
        M memory m1 = map["buy2_1"];

        //买起来
        (bool r,) = address(tradeFundPoolIns).call.value(value)(abi.encodeWithSignature("buy()"));
        Assert.equal(r,true,"buy failed");

        //事先预算 用value的值可以购买多少的fnd
        uint256 _fndAmount = sqrt(2 * value * 1000 / m1.slope + m1.totalSupply * m1.totalSupply) - m1.totalSupply;
        Assert.equal(_fndAmount,254,"_fndAmount is wrong");

        //发送交易之后合约的参数状况
        refreshParams("buy2_2");
        M memory m2 = map["buy2_2"];

        Assert.equal(m2.balance_fnd_this,m1.balance_fnd_this + _fndAmount,"buy fnd amount is wrong");//fnd的数量
        Assert.equal(m2.totalSupply,m1.totalSupply + _fndAmount,"totalSupply is wrong");//totalSupply
        Assert.equal(m2.sellReserve,m1.sellReserve + value * m1.alpha,"sellReserve is wrong "); //sellReserve
        Assert.equal(m2.totalSendToVote,m1.totalSendToVote + value * (1000 - m1.alpha),"sellReserve is wrong "); //sendtoVote
        Assert.equal(m2.balance_eth_vote,m1.balance_eth_vote + value * (1000 - m1.alpha) / 1000,"balance of govern is wrong");
        Assert.equal(m2.balance_eth_fundPool,m1.balance_eth_fundPool + value * m1.alpha / 1000,"balance of fund is wrong");

        //用了0.5eth
        Assert.equal(m2.balance_eth_this,m1.balance_eth_this - value,"sender value is wrong");
    }
*/
    /// @notice 转让fnd
    function testTransfer() public{
        uint256 amount = 200;
        TradeFundPool tradeFundPoolIns = TradeFundPool(DeployedAddresses.TradeFundPool());

        //先记录合约当前的一些参数
        refreshParams("transfer_1");
        M memory m1 = map["transfer_1"];

        //转点钱出去
        tradeFundPoolIns.transfer(tx.origin,amount);

        //发送交易之后合约的参数状况
        refreshParams("transfer_2");
        M memory m2 = map["transfer_2"];

        Assert.equal(m1.balance_fnd_this,m2.balance_fnd_this + 200,"fnd amount of this is wrong");
        Assert.equal(m1.balance_fnd_origin,m2.balance_fnd_origin - 200,"fnd amount of origin is wrong");
    }

    /// @notice 走利润回购接口购买fnd
    function testRevenue() public payable{
        uint256 value = 10 ether;
        TradeFundPool tradeFundPoolIns = TradeFundPool(DeployedAddresses.TradeFundPool());

        //先记录合约当前的一些参数
        refreshParams("revenue_1");
        M memory m1 = map["revenue_1"];

        //买起来
        (bool r,) = address(tradeFundPoolIns).call.value(value)(abi.encodeWithSignature("revenue()"));
        Assert.equal(r,true,"buy failed");

        //发送交易之后合约的参数状况
        refreshParams("revenue_2");
        M memory m2 = map["revenue_2"];

        //预算产生了多少fnd
        uint256 fndAmount = sqrt(2 * value * 1000 / m1.slope + m1.totalSupply * m1.totalSupply) - m1.totalSupply;
        Assert.equal(fndAmount,19964,"fndAmount is wrong");

        Assert.equal(m2.sellReserve,m1.sellReserve + value * m1.beta,"sellReserve is wrong");
        Assert.equal(m2.totalSendToVote,m1.totalSendToVote + value * (1000 - m1.beta),"totalSendToVote is wrong");
        Assert.equal(m2.balance_eth_fundPool,m1.balance_eth_fundPool + value * m1.beta / 1000,"balance of fund is wrong");
        Assert.equal(m2.balance_eth_vote,m1.balance_eth_vote + value * (1000 - m1.beta) / 1000,"balance of govern is wrong");
        Assert.equal(m2.totalSupply,m1.totalSupply + fndAmount,"totalSupply is wrong");

        Assert.equal(m2.balance_eth_fundPool + m2.balance_eth_this + m2.balance_eth_vote,150 ether,"eth lose");
    }

}