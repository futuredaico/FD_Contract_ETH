pragma solidity >=0.4.22 <0.6.0;
import "./TradeFundPool.sol";
import "./GovernManager.sol";

/// @title 自治管钱的合约
/// @author viko
/// @notice 只允许白名单中的合约调用，不允许其他地址调用
contract GovernFundPool{
    /// @notice 合约的拥有者
    address owner;

    /// @notice 与此合约绑定的资金池的合约
    TradeFundPool public tradeFundPool;

    /// @notice 自治管理合约
    GovernManager public governManager;

    /// @notice 最多允许锁股份次数
    uint8 lockTimesLimit = 5;

    /// @notice
    mapping(address => SL[]) slMap;

    /// @notice 用户存在治理合约中的fnd的数量
    mapping (address=>uint256) balances;

    /// @notice 用来记录提议合约的某个锁定到期时间
    struct SL {
        address contractAddress;
        uint256 index;
        uint256 expireDate;
        uint256 lockAmount;
        bool allowCancel;
    }

    constructor() public{
        owner = msg.sender;
    }

    /// @notice 设置tradefundPool合约
    function unsafe_setTradeFundPool(TradeFundPool _tradeFundPool) public{
        require(address(tradeFundPool) == address(0),"first init");
        tradeFundPool = _tradeFundPool;
    }

    /// @notice 要求白名单成员才能调用合约
    modifier isWhiteAddress(address _addr) {
        require(governManager.isWhiteAddress(_addr), "address is not whiteaddress");
        _;
    }

    /// @notice 获取某个地址拥有的可以投票的股份数量
    function getFndInGovernFundPool(address _addr) public view isWhiteAddress(msg.sender) returns(uint256){
        return balances[_addr];
    }

    /// @notice 获取某个地址拥有的不可以投票的股份数量
    function getFndInTradeFundPool(address _addr) public view isWhiteAddress(msg.sender) returns(uint256){
        return tradeFundPool.getBalance(_addr);
    }

    /// @notice 获取当前所有的股份数量
    function getFndTotalSupply() public view isWhiteAddress(msg.sender) returns(uint256){
        return tradeFundPool.totalSupply();
    }

    ///@notice 从tradefund合约中充钱进来
    function setFndIn(uint256 amount) public view returns(bool){
        require(amount>0,"amount need more than 0");
        bool r = tradeFundPool.transferFrom(msg.sender,address(this),amount);
        require(r,"lock error");
        balances[msg.sender] += amount;
        return true;
    }

    ///@notice 从tradefund合约中解锁股份
    function getFndOut(uint256 amount) public view returns(bool){
        require(amount>0,'amount need more than 0');
        require(balances[msg.sender]>=amount,"The balance is not enough");
        //先刷新一波
        refreshSL();
        bool r = tradeFundPool.transfer(msg.sender,amount);
        require(r,"free error");
        balances[msg.sender] -= amount;
    }

    /// @notice 增加某个锁定记录
    function addSL(
        address _lockAddr,
        address _contractAddr,
        uint256 _index,
        uint256 _expireDate,
        uint256 _lockAmount
    )
    private
    view
    returns(bool)
    {
        //锁定的股份不能超过余额
        require(balances[_addr] > 0,"Locked shares cannot exceed the balance");
        SL[] storage slQueue = slMap[_lockAddr];
        for(uint256 i = 0;i<slQueue.length;i++){
            SL storage _sl = slQueue[i];
            if(_sl.contractAddress == _contractAddr && _sl.expireDate == _expireDate && _sl.index == _index){
                _sl.lockAmount += _lockAmount;
                return true;
            }
        }

        SL sl = SL({
            contractAddress : _contractAddr,
            expireDate : _expireDate,
            index : _index,
            lockAmount : _lockAmount,
            allowCancel : _allowCancel
        });
        //不能超过锁定的次数
        require(lockTimesLimit <= slQueue.length,"Cannot exceed the number of locks");
        slMap[_lockAddr].push(sl);
        return true;
    }

    /// @notice 删除记录
    function delSL(
        address _lockAddr,
        address _contractAddr,
        uint256 _index,
        uint256 _expireDate
    )
    private
    view
    returns(bool)
    {
        SL[] storage slQueue = slMap[_lockAddr];
        for(uint256 i = 0;i<slQueue.length;i++){
            SL storage _sl = slQueue[i];
            if(_sl.contractAddress == _contractAddr && _sl.expireDate == _expireDate && _sl.index == _index){
                _sl = slQueue[slQueue.length - 1];
                delete slQueue[slQueue.length - 1];
                slQueue.length--;
                return true;
            }
        }
        return false;
    }

    /// @notice 刷新记录 剔除已经过期的记录
    function refreshSL() private view{
        SL[] storage slQueue = slMap[_lockAddr];
        for(uint256 i = 0;i<slQueue.length;i++){
            SL storage _sl = slQueue[i];
            if(_sl.expireDate > now){
                balances[_lockAddr] += _sl.lockAmount;
                _sl = slQueue[slQueue.length - 1];
                delete slQueue[slQueue.length - 1];
                slQueue.length--;
            }
        }
    }

    /// @notice 锁定股份（传入的是eth的值，需要先换成fnd的数量）
    function lock_eth_in(
        uint256 _lockAddr,
        uint256 _index,
        uint256 _expireDate,
        uint256 ethValue
    )
    public
    view
    isWhiteAddress(msg.sender)
    returns(bool)
    {
        uint256 needLock = tradeFundPool.invoke_buy(ethValue);
        return lock(_lockAddr,_index,_expireDate,needLock);
    }

    /// @notice 锁定股份
    function lock(uint256 _lockAddr,uint256 _index,uint256 _expireDate,uint256 _lockAmount) public view isWhiteAddress(msg.sender) returns(bool){
        //先刷新一波
        refreshSL();
        //锁定股份
        addSL(_lockAddr,msg,sender,_index,_expireDate,_lockAmount);
        return true;
    }

    /// @notice 解锁股份
    function free(uint256 _lockAddr,uint256 _index,uint256 _expireDate) public view isWhiteAddress(msg.sender) returns(bool){
        delSL(_lockAddr,msg,sender,_index,_expireDate);
    }

    /// @notice 给某个地址转账
    function sendEthToAddress(address payable _addr,uint256 _value) public payable isWhiteAddress(msg.sender){
        _addr.transfer(_value);
    }

/*
    /// @notice 调用合约做什么事情
    function callContract(address payable _addr,uint256 _value,bytes memory _execScript) public payable isWhiteAddress(msg.sender){
        (bool success,) = _addr.call.value(_value)(_execScript);
        require(success, "call failed");
    }
*/

    function() external payable{
    }
}