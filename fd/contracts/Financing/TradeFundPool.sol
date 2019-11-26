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
    /// @notice 是否开始募资
    bool public started = false;

    /// @notice 当前储备池中的存款
    uint256 public sellReserve;

    /// @notice 每个月非储备部分流出的百分比   乘以了1000
    uint256 public monthlyAllocationRatio_1000;
    /// @notice 每个月限制最大流出的金额
    uint256 public monthlyAllocationMaxValue;
    /// @notice 每个月限制最小流出的金额
    uint256 public monthlyAllocationMinValue;

    /// @notice 上一次领月供时的时间
    uint256 public preSendTimestamp;

    /////////////
    /// auth
    /////////////
    bytes32 public constant FundPool_Start = keccak256("FundPool_Start");
    bytes32 public constant FundPool_Clearing = keccak256("FundPool_Clearing");
    bytes32 public constant FundPool_ChangeRatio = keccak256("FundPool_ChangeRatio");

    //////////////
    //// 私有属性
    //////////////
    /// @notice 曲线合约
    ICurve private curve;

    /// @notice 发行的股份币的合约地址
    IERC20 private shares;

    /* events */
    /// @notice 购买
    event OnBuy(
        address who,
        uint256 assetValue,
        uint256 sharesAmount
    );

    /// @notice 出售
    event OnSell(
        address who,
        uint256 assetValue,
        uint256 sharesAmount
    );

    /// @notice 利润回购
    event OnRevenue(
        address who,
        uint256 assetValue
    );
    /// @notice 取钱
    /// @param who 哪个地址来取钱的
    /// @param assetValue 多少钱
    event OnSendToGovern(
        address who,
        uint256 assetValue
    );

    /// @notice 清退
    /// @param clearingContractAddress 处理清退的合约地址
    /// @param ratio 清退占所有股票的比例
    /// @param ethReserveAmount 清退了储备多少钱
    /// @param ethGovernAmount 清退了自治多少钱
    event OnClearing(
        address clearingContractAddress,
        uint256 ratio,
        uint256 ethReserveAmount,
        uint256 ethGovernAmount
    );

    event OnEvent(string tag);

    /// @notice 更改每月分配的比例和最大最小金额
    /// @param ratio 每月分配的比例
    /// @param minValue 最小的金额
    /// @param maxValue 最大的金额
    event OnChangeMonthlyAllocation(
        uint256 ratio,
        uint256 minValue,
        uint256 maxValue
    );

    /// @notice 构造函数
    constructor(
        AppManager _appManager,
        address _shares,
        address _curve,
        uint256 _monthlyAllocationRatio_1000,
        uint256 _monthlyAllocationMaxValue,
        uint256 _monthlyAllocationMinValue
        )
    FutureDaoApp(_appManager)
    public
    {
        curve = ICurve(_curve);
        shares = IERC20(_shares);
        assetAddress = _appManager.assetAddress();
        monthlyAllocationMinValue = _monthlyAllocationMinValue;
        monthlyAllocationMaxValue = _monthlyAllocationMaxValue;
        monthlyAllocationRatio_1000 = _monthlyAllocationRatio_1000;
    }

    /// @notice 判断是不是已经开始募资
    modifier isStart(){
        require(started == true,"need start");
        preSendTimestamp = now;
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
    function getSharesAddress() public view returns(address){
        return address(shares);
    }

    /////////////////
    ////合约操作方法
    ////////////////

    /// @notice 开始募资，一旦开始不能再停止
    function start() public auth(FundPool_Start) {
        started = true;
    }

    function changeMonthlyAllocation(uint256 _ratio,uint256 _minValue,uint256 _maxValue) public auth(FundPool_ChangeRatio) {
        //每次的修改不能超过50%
        uint256 _d = monthlyAllocationRatio_1000 > _ratio ? monthlyAllocationRatio_1000 - _ratio : _ratio - monthlyAllocationRatio_1000;
        require(_d.mul(1000).div(monthlyAllocationRatio_1000) < 500, "Over the limit");
        monthlyAllocationRatio_1000 = _ratio;
        monthlyAllocationMaxValue = _maxValue;
        monthlyAllocationMinValue = _minValue;
        emit OnChangeMonthlyAllocation(_ratio,_minValue,_maxValue);
    }

    /// @notice 投资者购买
    function buy(uint256 _assetValue,uint256 _minBuyToken,string memory tag) public payable isStart() {
        /// 给合约转钱
        transferF(msg.sender,address(this),_assetValue);
        uint256 sharesAmount = curve.getBuyAmount(_assetValue,shares.totalSupply());
        shares.mint(msg.sender,sharesAmount);
        require(sharesAmount >= _minBuyToken,"fdtAmount need more than _minBuyToken");
        //存在本合约储备池里的钱
        sellReserve = sellReserve.add(curve.getVauleToReserve(_assetValue));
        emit OnBuy(msg.sender,msg.value,sharesAmount);
        emit OnEvent(tag);
    }

    /// @notice 投资者出售
    /// @dev 如果在众筹阶段，是不允许出售股份的
    /// @param _amount 出售的股份数
    function sell(uint256 _amount,uint256 _minGasValue) public isStart() {
        require(_amount > 0,"amount need more than 0");
        uint256 withdraw = curve.getSellValue(_amount,sellReserve,shares.totalSupply());
        sellReserve = sellReserve.sub(withdraw);
        require(sellReserve >= 0,"sellReserve need more than 0");
        require(withdraw >= _minGasValue,"withdraw need less than _maxGasValue");
        shares.burn(msg.sender,_amount);
        transferM(msg.sender, withdraw);
        emit OnSell(msg.sender,withdraw,_amount);
    }

    /// @notice 投资的项目盈利，用这个接口购买股份
    /// @dev 钱直接冲进reserve 不产生fdt
    function revenue(uint256 _assetValue) public payable isStart(){
        /// 给合约转钱
        transferF(msg.sender,address(this),_assetValue);
        //存在本合约储备池里的钱
        sellReserve = sellReserve.add(_assetValue);
        emit OnRevenue(msg.sender,_assetValue);
    }

    /// @notice 申请资金转给自治部分
    function sendToGovern() public isStart(){
        /// 周期数
        uint256 periods = now.sub(preSendTimestamp).div(30 days);
        /// 时间到了没有
        require(periods > 0,"It's not time yet");
        uint256 sendValue = 0;
        uint256 balanceOfCanSend = balance(address(this)).sub(sellReserve);
        for(uint256 i = 0;i<periods;i++){
            uint256 _v = balanceOfCanSend.mul(monthlyAllocationRatio_1000).div(1000);
            _v = _v > monthlyAllocationMaxValue ? monthlyAllocationMaxValue : _v;
            _v = _v < monthlyAllocationMinValue ? monthlyAllocationMinValue : _v;
            sendValue += _v;
            balanceOfCanSend -= _v;
        }
        /// 发钱
        transferM(appManager.getGovernShareManager(),sendValue);
        preSendTimestamp = preSendTimestamp.add(periods.mul(30 days));
        emit OnSendToGovern(msg.sender,sendValue);
    }

    /// @notice 清退  ratio 乘以了 10 ** 3
    function clearing(address payable _clearingContractAddress,uint256 _ratio_1000)
    public isStart() auth(FundPool_Clearing){
        require(_ratio_1000<=10**3,"ratio is wrong");
        uint256 _value_reserve = (sellReserve).mul(_ratio_1000).div(10**3);
        uint256 _value_govern = (address(this)).balance.sub(sellReserve).mul(_ratio_1000).div(10**3);
        sellReserve = sellReserve.sub(_value_reserve);
        uint256 v = _value_reserve.add(_value_govern);
        transferM(_clearingContractAddress, v);
        emit OnClearing(_clearingContractAddress,_ratio_1000,_value_reserve,_value_govern);
    }

    function() external payable{
    }
}