pragma solidity >=0.4.22 <0.6.0;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/Financing/TradeFundPool.sol";
import "../contracts/Curve/Co.sol";
import "../contracts/apps/AppManager.sol";
import "../contracts/Token/FdToken.sol";

contract TestTradeFundPool {
    uint public initialBalance = 150 ether;

    /// @notice 检测appmanager是否正确赋值
    function testAppManagerIsRight() public{
        AppManager appManager = AppManager(DeployedAddresses.AppManager());
        TradeFundPool tradeFundPool = TradeFundPool(DeployedAddresses.TradeFundPool());
        Assert.equal(address(tradeFundPool.appManager()) == address(appManager),true,"AppManager address is wrong");
    }
    /// @notice 检测曲线是否正确赋值
    function testCoIsRight() public{
        Co co = Co(DeployedAddresses.Co());
        TradeFundPool tradeFundPool = TradeFundPool(DeployedAddresses.TradeFundPool());
        Assert.equal(address(tradeFundPool.curve()) == address(co),true,"co address is wrong");
    }
    /// @notice 检测token是否正确赋值
    function testTokenIsRight() public{
        FdToken token = FdToken(DeployedAddresses.FdToken());
        TradeFundPool tradeFundPool = TradeFundPool(DeployedAddresses.TradeFundPool());
        Assert.equal(address(tradeFundPool.token()) == address(token),true,"token address is wrong");
    }

    /// @notice 验证合约参数
    function testParams() public{
        TradeFundPool tradeFundPool = TradeFundPool(DeployedAddresses.TradeFundPool());
        Assert.equal(tradeFundPool.crowdFundDuringTime() == 30*24*60*60,true,"crowdFundDuringTime is wrong");
        Assert.equal(tradeFundPool.crowdFundMoney() == 10**20,true,"crowdFundMoney is wrong");
        Assert.equal(tradeFundPool.crowdFundPrice(),223606000000000,"crowdFundPrice is wrong");
    }

    /// @notice 没有开始的时候 合约某些方法是禁止调用的
    function testSomeFuncWhenNoBeginning() public{
        TradeFundPool tradeFundPoolIns = TradeFundPool(DeployedAddresses.TradeFundPool());
        bool r;
        r = tradeFundPoolIns.started();
        Assert.isFalse(r,"need false");

        (r,) = address(tradeFundPoolIns).call.value(10000)(abi.encodeWithSignature("crowdfunding(bool)",false));
        Assert.isFalse(r,"need false");

        (r,) = address(tradeFundPoolIns).call(abi.encodeWithSignature("windingUp()"));
        Assert.isFalse(r,"need false");

        (r,) = address(tradeFundPoolIns).call.value(100000)(abi.encodeWithSignature("buy()"));
        Assert.isFalse(r,"need false");

        (r,) = address(tradeFundPoolIns).call(abi.encodeWithSignature("sell(uint256)",10));
        Assert.isFalse(r,"need false");

        (r,) = address(tradeFundPoolIns).call.value(100000)(abi.encodeWithSignature("revenue()"));
        Assert.isFalse(r,"need false");
    }

        /// @notice 预发售股份
    function testPreMint() public{
        AppManager appManagerIns = AppManager(DeployedAddresses.AppManager());
        TradeFundPool tradeFundPoolIns = TradeFundPool(DeployedAddresses.TradeFundPool());
        FdToken fdToken = FdToken(DeployedAddresses.FdToken());
        //////先增加权限
        //运行root调用premint
        appManagerIns.addPermission(tx.origin,address(tradeFundPoolIns),keccak256("FundPool_PreMint"));

        bool r;
        (r,) =address(tradeFundPoolIns).call(abi.encodeWithSignature("preMint(address,uint256)",tx.origin,100));
        Assert.equal(r,true,"need true");

        uint256 balance = fdToken.balanceOf(tx.origin);
        Assert.equal(balance,100,"fnd amount is wrong");
    }
}