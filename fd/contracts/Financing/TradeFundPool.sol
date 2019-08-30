pragma solidity >=0.4.22 <0.6.0;

import "../Interface/ITradeFundPool.sol";
import "../apps/FutureDaoApp.sol";
import "../Interface/ICurve.sol";
import "../Interface/IERC20.sol";

/// @title 资金池，用来接受eth并发行股份币
/// @author viko
/// @notice 你可以进行股份的众筹，出售，购买，交易。
/// @dev 最开始可以设置一个预期众筹目前和众筹时的股价，众筹期内购买的价格都是一样的。众筹如果未达标，原路返回所有的钱。如果达标了，开始根据购买曲线和出售曲线进行购买和出售操作。
contract TradeFundPool is ITradeFundPool , FutureDaoApp{
    /// @notice 众筹时的每股价格
    uint256 public crowdFundPrice;

    /// @notice 众筹的时间
    uint256 public crowdFundDuringTime;

    /// @notice 众筹的目标
    uint256 public crowdFundMoney;

    /// @notice 众筹开始时间
    uint256 public crowdFundStartTime;

    /// @notice 是否处于众筹期间
    bool public during_crowdfunding = true;

    /// @notice 是否开始募资
    bool public started = false;

    /// @notice 当前储备池中的存款
    uint256 public sellReserve;

    /// @notice 众筹期间募集的eth
    mapping (address=>uint256) public crowdFundingEth;

    /////////////
    /// auth
    /////////////
    bytes32 public constant FundPool_Start = keccak256("FundPool_Start");
    bytes32 public constant FundPool_PreMint = keccak256("FundPool_PreMint");
    bytes32 public constant FundPool_SendEth = keccak256("FundPool_SendEth");
    //bytes32 public constant FundPool_crowdfunding = keccak256("FundPool_crowdfunding");

    //////////////
    //// 私有属性
    //////////////
    /// @notice 曲线合约
    ICurve private curve;

    /// @notice 发行的股份币的合约地址
    IERC20 private token;

    /* events */
    /// @notice 购买
    event OnBuy(
        address who,
        uint256 ethAmount,
        uint256 fdtAmount
    );

    /// @notice 出售
    event OnSell(
        address who,
        uint256 ethAmount,
        uint256 fdtAmount
    );

    /// @notice 利润回购
    event OnRevenue(
        address who,
        uint256 ethAmount
    );

    /// @notice 清退
    event OnWindingUp(
        address who,
        uint256 ethAmount
    );

    /// @notice 预挖矿
    event OnPreMint(
        address who,
        uint256 fdtAmount
    );

    /// @notice 构造函数
    /// @param _duringTime 众筹的时间，_money 众筹的目标资金
    constructor(AppManager _appManager,IERC20 _token,uint256 _duringTime,uint256 _money,ICurve _curve) public{
        require(_duringTime > 0, "d need greater than 0");
        require(_money > 0, "m need greater than 0");
        curve = _curve;
        appManager = _appManager;
        token = _token;
        crowdFundDuringTime = _duringTime;
        crowdFundMoney = _money;
        crowdFundStartTime = now;
        crowdFundPrice = curve.getCrowdFundPrice(crowdFundMoney);
    }

    /// @notice 判断是不是已经开始募资
    modifier isStart(){
        require(started == true,"need start");
        _;
    }

    /// @notice 判断是不是在众筹期
    modifier isCrowdfunding(){
        require(during_crowdfunding == true,"need to be in a crowdfunding period");
        _;
    }

    /// @notice 判断不在众筹期
    modifier isNotCrowdfunding(){
        require(during_crowdfunding == false,"Need not be in crowdfunding period");
        _;
    }

    /////////////////
    ////查询 方法
    ////////////////

    /// @notice 查询曲线合约的地址
    function getCurveAddress() public view returns(address) {
        return address(curve);
    }

    /// @notice 查询股份币合约的地址
    function getFdTokenAddress() public view returns(address){
        return address(token);
    }

    /////////////////
    ////合约操作方法
    ////////////////

    /// @notice 开始募资，一旦开始不能再停止
    function start() public auth(FundPool_Start) {
        started = true;
    }

    /// @notice 预挖矿
    function preMint(address who,uint256 amount) public auth(FundPool_PreMint){
        require(started == false,"cant start");
        token.mint(who,amount);
        emit OnPreMint(who,amount);
    }

    /// @notice 众筹失败，清退
    /// @dev 如果在众筹阶段，是不允许清退的
    function windingUp() public isStart() isCrowdfunding() {
        require(crowdFundingEth[msg.sender] > 0,"need has eth");
        require(now.sub(crowdFundStartTime) > crowdFundDuringTime, "need beyond the corwdfunding period");
        uint256 value = crowdFundingEth[msg.sender];
        msg.sender.transfer(value);
        crowdFundingEth[msg.sender] = 0;
        //吧token也销毁了
        token.burn(msg.sender,token.totalSupply());
        emit OnWindingUp(msg.sender,value);
    }

    /// @notice 众筹
    /// @dev 众筹期间价格是固定的，不需要走购买曲线,期间所有的钱都进入储备池，需要考虑的是零界点的处理
    function crowdfunding(bool needBack) public payable isStart() isCrowdfunding(){
        uint256 invest = msg.value;
        require(invest > 0,"value need more than 0");
        require(now.sub(crowdFundStartTime) <= crowdFundDuringTime,"need in the corwdfunding period");
        uint256 balance = address(this).balance;
        if(balance < crowdFundMoney){//如果没有达到众筹要求
            uint256 fdtAmount = invest.div(crowdFundPrice);
            token.mint(msg.sender,fdtAmount);
            sellReserve = sellReserve.add(curve.getVauleToReserve(invest));
            crowdFundingEth[msg.sender] = crowdFundingEth[msg.sender].add(invest);
        }
        else if(balance == crowdFundMoney){//如果正好达到众筹要求
            during_crowdfunding = false;
            uint256 fdtAmount = invest.div(crowdFundPrice);
            token.mint(msg.sender,fdtAmount);
            sellReserve = sellReserve.add(curve.getVauleToReserve(invest));
            crowdFundingEth[msg.sender] = crowdFundingEth[msg.sender].add(invest);
        }
        else if(needBack){//如果超出了众筹要求且超出部分要求退回
            during_crowdfunding = false;
            uint256 needValue = invest.sub(address(this).balance.sub(crowdFundMoney));
            uint256 fdtAmount = needValue.div(crowdFundPrice);
            token.mint(msg.sender,fdtAmount);
            //退还超出的eth
            msg.sender.transfer(invest.sub(needValue));
            sellReserve = sellReserve.add(curve.getVauleToReserve(needValue));
            crowdFundingEth[msg.sender] = crowdFundingEth[msg.sender].add(needValue);
        }
        else{//超出了众筹要求，超出部分不需要退回，继续走曲线购买
            during_crowdfunding = false;
            uint256 needValue = invest.sub(address(this).balance.sub(crowdFundMoney));
            uint256 fdtAmount = needValue.div(crowdFundPrice);
            token.mint(msg.sender,fdtAmount);
            uint256 fdtAmount2 = curve.getBuyAmount(invest.sub(needValue),token.totalSupply());
            token.mint(msg.sender,fdtAmount2);
            sellReserve = sellReserve.add(curve.getVauleToReserve(invest));
            crowdFundingEth[msg.sender] = crowdFundingEth[msg.sender].add(invest);
        }
    }

    /// @notice 投资者购买
    function buy() public payable isStart() isNotCrowdfunding(){
        require(msg.value > 0,"value need more than 0");
        uint256 invest = msg.value;
        uint256 fdtAmount = curve.getBuyAmount(invest,token.totalSupply());
        token.mint(msg.sender,fdtAmount);
        //存在本合约储备池里的钱
        sellReserve = sellReserve.add(curve.getVauleToReserve(invest));
        emit OnBuy(msg.sender,msg.value,fdtAmount);
    }

    /// @notice 投资者出售
    /// @dev 如果在众筹阶段，是不允许出售股份的
    /// @param _amount 出售的股份数
    function sell(uint256 _amount) public isStart() isNotCrowdfunding(){
        require(_amount > 0,"amount need more than 0");
        uint256 withdraw = curve.getSellValue(_amount,sellReserve,token.totalSupply());
        sellReserve = sellReserve.sub(withdraw);
        require(sellReserve >= 0,"sellReserve need more than 0");
        token.burn(msg.sender,_amount);
        msg.sender.transfer(withdraw);
        emit OnSell(msg.sender,withdraw,_amount);
    }

    /// @notice 投资的项目盈利，用这个接口购买股份
    /// @dev 钱直接冲进reserve 不产生fdt
    function revenue() public payable isStart() isNotCrowdfunding(){
        require(msg.value > 0,"value need more 0");
        uint256 invest = msg.value;
        //存在本合约储备池里的钱
        sellReserve = sellReserve.add(invest);
        emit OnRevenue(msg.sender,invest);
    }

    /// @notice 动用合约的钱  需要权限验证
    function sendEth(address payable _who,uint256 _value) public isStart() isNotCrowdfunding() auth(FundPool_SendEth){
        //需要确保不能用到 储备池 中的钱
        require(address(this).balance.sub(_value) > sellReserve, "not sufficient funds");

        _who.transfer(_value);
    }

    function() external payable{
    }
}