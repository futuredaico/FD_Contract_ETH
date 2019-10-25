pragma solidity >=0.4.22 <0.6.0;

import "../Interface/IGovernShareManager.sol";
import "../apps/FutureDaoApp.sol";
import "../Interface/IERC20.sol";
import "../Interface/ITradeFundPool.sol";
import "../clearing/ClearingFundPool.sol";


/// @title 自治管钱的合约
/// @author viko
/// @notice 只允许白名单中的合约调用，不允许其他地址调用
contract GovernShareManager is FutureDaoApp , IGovernShareManager{
    /// @notice 最多允许锁股份次数
    uint8 lockTimesLimit = 5;

    /// @notice
    mapping(address => SL[]) slMap;

    /// @notice 用户存在治理合约中的Fdt的数量
    mapping (address=>uint256) balances;

    /// @notice 用户必须锁定的时间和数量，不是额外的，包含在balances中。只是表示其中的一部分需要锁定到什么时候
    mapping (address=>Sbinding[]) map_Sbinding;

    /// @notice 发行的股份币的合约地址
    address public token;

    bytes32 public constant GovernShareManager_MintBinding = keccak256("GovernShareManager_MintBinding");
    bytes32 public constant GovernShareManager_Lock = keccak256("GovernShareManager_Lock");
    bytes32 public constant GovernShareManager_Free = keccak256("GovernShareManager_Free");
    bytes32 public constant GovernShareManager_SendEth = keccak256("GovernShareManager_SendEth");
    bytes32 public constant GovernShareManager_Clearing = keccak256("GovernShareManager_Clearing");
    bytes32 public constant GovernShareManager_ClearingFdt = keccak256("GovernShareManager_ClearingFdt");

    //// 这部分的锁定 是不能提取出合约，但是能投票的那种
    struct Sbinding{
        uint256 amount;
        uint timestamp;
    }

    /// @notice 用来记录提议合约的某个锁定到期时间
    struct SL {
        address contractAddress;
        uint256 index;
        uint256 expireDate;
        uint256 lockAmount;
    }

    /// @notice 将fdt从本合约中取出
    /// @param who 交易发起者
    /// @param amount 数额
    event OnGetFdtOut(address who,uint256 amount);

    /// @notice 将fdt存入本合约以投票
    /// @param who 交易发起者
    /// @param amount 数额
    event OnSetFdtIn(address who,uint256 amount);

    /// @notice 锁定fdt
    /// @param contractAddress 哪个合约申请的锁币
    /// @param lockAddr 锁哪个地址的币
    /// @param index 标识序列号
    /// @param expireDate 到期时间
    /// @param lockAmount 锁定的数量
    event OnLock(address contractAddress,address lockAddr,uint256 index,uint256 expireDate,uint256 lockAmount);

    /// @notice 解锁fdt
    /// @param contractAddress 哪个合约申请的锁币
    /// @param lockAddr 锁哪个地址的币
    /// @param index 标识序列号
    /// @param expireDate 到期时间
    event OnFree(address contractAddress,address lockAddr,uint256 index,uint256 expireDate);

    constructor(AppManager _appManager,address _token)  FutureDaoApp(_appManager) public {
        token = _token;
    }

    /// @notice 获取某个地址拥有的可以投票的股份数量
    function getFdtInGovern(address _addr) public view returns(uint256) {
        return balances[_addr];
    }

    /// @notice 获取fdt总发行量
    function getFdtTotalSupply() public view returns(uint256){
        uint256 totalSupplyInFdt = IERC20(token).totalSupply();
        return totalSupplyInFdt;
    }

    function mintBinding(address _addr,uint256 _amount,uint256 _timestamp)
    public auth(GovernShareManager_MintBinding) returns(bool){
        balances[_addr] = balances[_addr].add(_amount);
        Sbinding memory binding = Sbinding({
            amount : _amount,
            timestamp : _timestamp
        });
        map_Sbinding[msg.sender].push(binding);
        return true;
    }

    ///@notice 充钱进来
    function setFdtIn(uint256 _amount) public returns(bool) {
        require(_amount>0,"amount need more than 0");
        bool r = IERC20(token).transferFrom(msg.sender,address(this),_amount);
        require(r,"lock error");
        emit OnSetFdtIn(msg.sender,_amount);
        return true;
    }

    ///@notice 拿钱出去
    function getFdtOut(uint256 amount) public returns(bool){
        require(amount>0,'amount need more than 0');
        uint256 _bindingAmount = _getbindingAmount(msg.sender);
        require(balances[msg.sender].sub(_bindingAmount) >= amount,"The balance is not enough");
        // //先刷新一波
        // _refreshSL(msg.sender);
        bool r = IERC20(token).transfer(msg.sender,amount);
        require(r,"free error");
        balances[msg.sender] = balances[msg.sender].sub(amount);
        emit OnGetFdtOut(msg.sender,amount);
    }

    /// @notice 锁定股份
    function lock(address _lockAddr,uint256 _index,uint256 _expireDate,uint256 _lockAmount)
    public
    auth(GovernShareManager_Lock)
    returns(bool)
    {
        // //先刷新一波
        // _refreshSL(_lockAddr);
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

    /// @notice 清退fdt
    function clearingFdt(address payable _addr_clearingFundPool,address _addr,uint256 amount) public auth(GovernShareManager_ClearingFdt)
    returns(bool)
    {
        // //先刷新一波
        // _refreshSL(_addr);
        require(balances[_addr].sub(amount)>0,"no money");
        IERC20(token).approve(_addr_clearingFundPool,amount);
        bool r = ClearingFundPool(_addr_clearingFundPool).lock(_addr,amount);
        balances[_addr] = balances[_addr].sub(amount);
        require(r==true,"error");
    }

    /// @notice 给某个地址转账
    function sendEth(address payable _addr,uint256 _value) public payable auth(GovernShareManager_SendEth) returns(bool){
        ITradeFundPool(appManager.getTradeFundPool()).sendEth(_addr,_value);
    }

    /// @notice 清退
    function clearing(address payable _addr_clearingFundPool,uint256 _ratio) public payable auth(GovernShareManager_Clearing) returns(bool){
        ITradeFundPool(appManager.getTradeFundPool()).clearing(_addr_clearingFundPool,_ratio);
        return true;
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
                balances[_lockAddr] = balances[_lockAddr].sub(_lockAmount);
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
        require(slQueue.length <= lockTimesLimit,"Cannot exceed the number of locks");
        slMap[_lockAddr].push(sl);
        balances[_lockAddr] = balances[_lockAddr].sub(_lockAmount);
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
        for(int i = 0;i < int(slQueue.length);i++){
            SL storage _sl = slQueue[uint(i)];
            if(_sl.contractAddress == _contractAddr && _sl.expireDate == _expireDate && _sl.index == _index){
                balances[_lockAddr] = balances[_lockAddr].add(_sl.lockAmount);
                _sl = slQueue[slQueue.length.sub(1)];
                delete slQueue[slQueue.length.sub(1)];
                slQueue.length = slQueue.length.sub(1);
                i = i - 1;
                return true;
            }
        }
        return false;
    }

    // /// @notice 刷新记录 剔除已经过期的记录
    // function _refreshSL(address _lockAddr) private {
    //     SL[] storage slQueue = slMap[_lockAddr];
    //     for(int i = 0;i<int(slQueue.length);i++){
    //         SL storage _sl = slQueue[uint(i)];
    //         if(_sl.expireDate > now){
    //             balances[_lockAddr] = balances[_lockAddr].add(_sl.lockAmount);
    //             _sl = slQueue[slQueue.length.sub(1)];
    //             delete slQueue[slQueue.length.sub(1)];
    //             slQueue.length = slQueue.length.sub(1);
    //             i = i-1;
    //         }
    //     }
    // }

/*
    /// @notice 调用合约做什么事情
    function callContract(address payable _addr,uint256 _value,bytes memory _execScript) public payable isWhiteAddress(msg.sender){
        (bool success,) = _addr.call.value(_value)(_execScript);
        require(success, "call failed");
    }
*/

    function _getbindingAmount(address _addr) private returns(uint256 _bindingAmount){
        _bindingAmount = 0;
        Sbinding[] storage queue = map_Sbinding[_addr];
        for(int i = 0;i < int(queue.length);i++){
            Sbinding storage _sb = queue[uint(i)];
            if(now < _sb.timestamp){
                _bindingAmount = _bindingAmount.add(_sb.amount);
            }
            else{
                _sb = queue[queue.length.sub(1)];
                delete queue[queue.length.sub(1)];
                queue.length = queue.length.sub(1);
                i = i - 1;
            }
        }
        return _bindingAmount;
    }

    function() external payable{
    }
}