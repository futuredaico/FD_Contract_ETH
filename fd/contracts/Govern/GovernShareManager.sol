pragma solidity >=0.4.22 <0.6.0;

import "./IGovernShareManager.sol";
import "../apps/FutureDaoApp.sol";
import "../lib/IERC20.sol";
import "../Financing/ITradeFundPool.sol";


/// @title 自治管钱的合约
/// @author viko
/// @notice 只允许白名单中的合约调用，不允许其他地址调用
contract GovernShareManager is IGovernShareManager , FutureDaoApp{
    /// @notice 最多允许锁股份次数
    uint8 lockTimesLimit = 5;

    /// @notice
    mapping(address => SL[]) slMap;

    /// @notice 用户存在治理合约中的Fdt的数量
    mapping (address=>uint256) balances;

    /// @notice 发行的股份币的合约地址
    IERC20 public token;

    bytes32 public constant GovernShareManager_Lock = keccak256("GovernShareManager_Lock");
    bytes32 public constant GovernShareManager_Free = keccak256("GovernShareManager_Free");
    bytes32 public constant GovernShareManager_SendEth = keccak256("GovernShareManager_SendEth");


    /// @notice 用来记录提议合约的某个锁定到期时间
    struct SL {
        address contractAddress;
        uint256 index;
        uint256 expireDate;
        uint256 lockAmount;
    }

    constructor(AppManager _appManager,IERC20 _token) public{
        appManager = _appManager;
        token = _token;
    }

    /// @notice 获取某个地址拥有的可以投票的股份数量
    function getFdtInGovern(address _addr) public returns(uint256){
        return balances[_addr];
    }

    /// @notice 获取fdt总发行量
    function getFtdTotalSupply() public returns(uint256){
        return token.totalSupply();
    }

    ///@notice 从tradefund合约中充钱进来
    function setFdtIn(uint256 amount) public returns(bool){
        require(amount>0,"amount need more than 0");
        bool r = token.transferFrom(msg.sender,address(this),amount);
        require(r,"lock error");
        balances[msg.sender] = balances[msg.sender].add(amount);
        return true;
    }

    ///@notice 从tradefund合约中解锁股份
    function getFdtOut(uint256 amount) public returns(bool){
        require(amount>0,'amount need more than 0');
        require(balances[msg.sender]>=amount,"The balance is not enough");
        //先刷新一波
        _refreshSL(msg.sender);
        bool r = token.transfer(msg.sender,amount);
        require(r,"free error");
        balances[msg.sender] = balances[msg.sender].sub(amount);
    }

    /// @notice 锁定股份
    function lock(address _lockAddr,uint256 _index,uint256 _expireDate,uint256 _lockAmount)
    public
    auth(GovernShareManager_Lock)
    returns(bool)
    {
        //先刷新一波
        _refreshSL(_lockAddr);
        //锁定股份
        _addSL(_lockAddr,msg.sender,_index,_expireDate,_lockAmount);
        return true;
    }

    /// @notice 解锁股份
    function free(address _lockAddr,uint256 _index,uint256 _expireDate)
    public
    auth(GovernShareManager_Free)
    returns(bool)
    {
        _delSL(_lockAddr,msg.sender,_index,_expireDate);
    }


    /// @notice 给某个地址转账
    function sendEth(address payable _addr,uint256 _value) public payable auth(GovernShareManager_SendEth) returns(bool){
        ITradeFundPool(appManager.getTradeFundPool()).sendEth(_addr,_value);
    }

/////////////////////
///私有方法
////////////////////

    /// @notice 增加某个锁定记录
    function _addSL(
        address _lockAddr,
        address _contractAddr,
        uint256 _index,
        uint256 _expireDate,
        uint256 _lockAmount
    )
    private
    returns(bool)
    {
        //锁定的股份不能超过余额
        require(balances[_lockAddr] > 0,"Locked shares cannot exceed the balance");
        SL[] storage slQueue = slMap[_lockAddr];
        for(uint256 i = 0;i<slQueue.length;i = i.add(1)){
            SL storage _sl = slQueue[i];
            if(_sl.contractAddress == _contractAddr && _sl.expireDate == _expireDate && _sl.index == _index){
                _sl.lockAmount = _sl.lockAmount.add(_lockAmount);
                return true;
            }
        }

        SL memory sl = SL({
            contractAddress : _contractAddr,
            expireDate : _expireDate,
            index : _index,
            lockAmount : _lockAmount
        });
        //不能超过锁定的次数
        require(lockTimesLimit <= slQueue.length,"Cannot exceed the number of locks");
        slMap[_lockAddr].push(sl);
        return true;
    }

    /// @notice 删除记录
    function _delSL(
        address _lockAddr,
        address _contractAddr,
        uint256 _index,
        uint256 _expireDate
    )
    private
    returns(bool)
    {
        SL[] storage slQueue = slMap[_lockAddr];
        for(uint256 i = 0;i < slQueue.length;i = i.add(1)){
            SL storage _sl = slQueue[i];
            if(_sl.contractAddress == _contractAddr && _sl.expireDate == _expireDate && _sl.index == _index){
                _sl = slQueue[slQueue.length.sub(1)];
                delete slQueue[slQueue.length.sub(1)];
                slQueue.length = slQueue.length.sub(1);
                return true;
            }
        }
        return false;
    }

    /// @notice 刷新记录 剔除已经过期的记录
    function _refreshSL(address _lockAddr) private {
        SL[] storage slQueue = slMap[_lockAddr];
        for(uint256 i = 0;i<slQueue.length;i = i.add(1)){
            SL storage _sl = slQueue[i];
            if(_sl.expireDate > now){
                balances[_lockAddr] = balances[_lockAddr].add(_sl.lockAmount);
                _sl = slQueue[slQueue.length.sub(1)];
                delete slQueue[slQueue.length.sub(1)];
                slQueue.length = slQueue.length.sub(1);
            }
        }
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