pragma solidity >=0.4.22 <0.6.0;
import "./Vote.sol";

/// @title 资金池，用来接受eth并发行股份币
/// @author viko
/// @notice 你可以进行股份的众筹，出售，购买，交易。
/// @dev 最开始可以设置一个预期众筹目前和众筹时的股价，众筹期内购买的价格都是一样的。众筹如果未达标，原路返回所有的钱。如果达标了，开始根据购买曲线和出售曲线进行购买和出售操作。
contract N_FundPool{
    ///@notice 购买时的斜率
    uint256 public slope = 10**12;

    /// @notice 投资者购买时所使用的分子，意味着7成进入储备，3成进入自治；
    uint256 public alpha = 700;

    /// @notice 项目盈利时购买使用的分子
    uint256 public beta = 800;

    /// @notice 众筹时的每股价格
    uint256 public crowdFundPrice = 1;

    /// @notice 众筹的天数 单位是天
    uint256 public crowdFundDays = 30;

    /// @notice 众筹的目标
    uint256 public crowdFundMoney = 10000;

    /// @notice 众筹开始时间
    uint256 public crowdFundStartTime;

    /// @notice 是否处于众筹期间
    bool public during_crowdfunding = true;

    /// @notice 项目名称
    string public name;

    /// @notice fnd发行的总量
    uint256 public totalSupply = 0;

    /// @notice 合约的拥有着
    address public owner;

    /// @notice 是否开始募资
    bool public started = false;

    /// @notice 当前储备池中的存款
    uint256 public sellReserve = 0;

    /// @notice 发送给项目方的钱总数
    uint256 public totalSendToVote = 0;

    /// @notice 自治合约
    N_Vote vote;

    /// @notice 众筹期间募集的eth
    mapping (address=>uint256) public crowdFundingEth;

    /// @notice 记录每个地址拥有的fnd数量
    mapping(address=>uint256) public balances;

    /// @notice 记录每个地址拥有的锁定的fnd的数量
    mapping(uint256 => mapping(address=>uint256)) public lock_balances;

    /// @notice 清退锁定的存款
    mapping (uint256 => uint256) clearingValue;

    /// @notice 清退的fnd的数量
    mapping (uint256 => uint256)  clearingTotalFnd;

    /* events */
    /// @notice 购买
    event OnBuy(
        address who,
        uint256 ethAmount,
        uint256 nfdAmount
    );

    /// @notice 出售
    event OnSell(
        address who,
        uint256 ethAmount,
        uint256 nfdAmount
    );

    /// @notice 利润回购
    event OnRevenue(
        address who,
        uint256 ethAmount,
        uint256 nfdAmount
    );

    /// @notice 清退
    event OnWindingUp(
        address who,
        uint256 ethAmount
    );

    /// @notice 预挖矿
    event OnPreMint(
        address who,
        uint256 nfdAmount
    );

    /// @notice 构造函数
    /// @param _name 项目的名称，d 众筹的天数，m 众筹的目标资金
    constructor(string memory _name,uint256 d,uint256 m,uint256 s,uint256 a, uint256 b) public{
        owner = msg.sender;
        require(bytes(_name).length > 0,"name cant be empty");
        require(d > 0, "d need greater than 0");
        require(m > 0, "m need greater than 0");
        require(s > 0, "s need greater than 0");
        require(a > 0, "a need greater than 0");
        require(b > 0, "b need greater than 0");
        name = _name;
        crowdFundDays = d;
        crowdFundMoney = m;
        crowdFundStartTime = now;
        crowdFundPrice = sqrt(2 * m * 1000 / slope) / 2;
        slope = s;
        alpha = a;
        beta = b;
        vote = new N_Vote(owner,this);
    }

    /// @notice 判断是不是合约的所有者
    modifier isOwner() {
        require(owner == msg.sender, "limited authority");
        _;
    }

    /// @notice 判断是不是已经开始募资
    modifier isStart(){
        require(started == true,"need start");
        _;
    }

    /// @notice 获取vote合约
    /// @return vote合约的地址
    function getVoteContract() public view returns(address){
        return address(vote);
    }

    /// @notice 开始募资，一旦开始不能再停止
    function start() public isOwner() {
        started = true;
    }

    /// @notice 预挖矿
    function preMint(address who,uint256 amount) public isOwner() {
        require(started == false,"cant start");
        balances[who] += amount;
        totalSupply += amount;
        emit OnPreMint(who,amount);
    }

    /// @notice 管理员重新设置购买斜率
    /// @param _slope 新的购买斜率
    function setSlope(uint256 _slope) public isOwner() {
        slope = _slope;
    }

    /// @notice 管理员重新设置购买时分配给自治池钱的比例
    /// @param _alpha 新的比例
    function setAlpha(uint256 _alpha) public isOwner() {
        alpha = _alpha;
    }

    /// @notice 管理员重新设置利润回购时分配给自治池钱的比例
    /// @param _beta 新的比例
    function setBeta(uint256 _beta) public isOwner() {
        beta = _beta;
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

    /// @notice 众筹失败，清退
    /// @dev 如果在众筹阶段，是不允许清退的
    function windingUp() public isStart() {
        require(now - crowdFundStartTime > 30 days,"need beyond the corwdfunding period");
        require(during_crowdfunding == true,"need corwdfunding");
        require(crowdFundingEth[msg.sender] > 0,"need has eth");
        uint256 value = crowdFundingEth[msg.sender];
        msg.sender.transfer(value);
        crowdFundingEth[msg.sender] = 0;
        emit OnWindingUp(msg.sender,value);
    }

    /// @notice 众筹
    /// @dev 众筹期间价格是固定的，不需要走购买曲线,期间所有的钱都进入储备池，需要考虑的是零界点的处理
    function crowdfunding(bool needBack) public payable isStart() {
        uint256 invest = msg.value;
        require(invest > 0,"value need more than 0");
        require(during_crowdfunding == true,"need corwdfunding");
        uint256 all = invest * 1000 + sellReserve;
        if(all < crowdFundMoney * 1000){//如果没有达到众筹要求
            uint256 fndAmount = invest / crowdFundPrice;
            balances[msg.sender] += fndAmount;
            totalSupply += fndAmount;
            sellReserve += invest * 1000;
        }
        else if(all == crowdFundMoney * 1000){//如果正好达到众筹要求
            during_crowdfunding = false;
            uint256 fndAmount = invest / crowdFundPrice;
            balances[msg.sender] += fndAmount;
            totalSupply += fndAmount;
            sellReserve += invest * 1000;
            address(vote).transfer(sellReserve);
            totalSendToVote = sellReserve;
            sellReserve = 0;
        }
        else if(needBack){//如果超出了众筹要求且超出部分要求退回
            during_crowdfunding = false;
            uint256 needValue = crowdFundMoney * 1000 - sellReserve;
            uint256 fndAmount = needValue / crowdFundPrice;
            balances[msg.sender] += fndAmount;
            totalSupply += fndAmount;
            msg.sender.transfer(invest - needValue);
            sellReserve += needValue * 1000;
            address(vote).transfer(sellReserve);
            totalSendToVote = sellReserve;
            sellReserve = 0;
        }
        else{//超出了众筹要求，超出部分不需要退回，继续走曲线购买
            during_crowdfunding = false;
            uint256 needValue = crowdFundMoney - sellReserve;
            uint256 fndAmount = needValue / crowdFundPrice;
            fndAmount += sqrt(2 * (invest - needValue) * 1000 / slope + totalSupply * totalSupply) - totalSupply;
            balances[msg.sender] += fndAmount;
            totalSupply += fndAmount;
            uint256 sendToVote = (1000 - alpha) * (invest - needValue);
            address(vote).transfer(sendToVote);
            totalSendToVote += sendToVote;
            sellReserve += (invest - sendToVote) * 1000;
        }
    }

    /// @notice 投资者购买
    function buy() public payable isStart() {
        require(msg.value > 0,"value need more than 0");
        uint256 invest = msg.value;
        uint256 fndAmount = sqrt(2 * invest * 1000 / slope + totalSupply * totalSupply) - totalSupply;
        balances[msg.sender] += fndAmount;
        totalSupply += fndAmount;
        //存在本合约储备池里的钱
        sellReserve += alpha * invest;
        //发给项目池用作发展的钱
        uint256 sendToVote = (1000-alpha) * invest;
        totalSendToVote += sendToVote;
        sendToVote /= 1000;
        if(during_crowdfunding == false){//如果不在众筹期了，转部分钱给vote
            address(vote).transfer(sendToVote);
        }
        else if(totalSendToVote+sellReserve>=crowdFundMoney * 1000){
            require(now - crowdFundStartTime <= 30 days,"Beyond the during_crowdfunding period");
            during_crowdfunding = false;
            address(vote).transfer(totalSendToVote/1000);
        }
        else{
            crowdFundingEth[msg.sender] += msg.value;
            require(now - crowdFundStartTime <= 30 days,"Beyond the during_crowdfunding period");
        }

        emit OnBuy(msg.sender,msg.value,fndAmount);
    }

    /// @notice 投资者出售
    /// @dev 如果在众筹阶段，是不允许出售股份的
    /// @param amount 出售的股份数
    function sell(uint256 amount) public isStart() {
        require(!during_crowdfunding,"need Beyond the during_crowdfunding period");
        require(amount > 0,"amount need more than 0");
        require (balances[msg.sender] >= amount,"balance of sender need more than 0");
        uint256 withdraw = sellReserve*amount*(2*totalSupply - amount)/totalSupply/totalSupply;
        balances[msg.sender] -= amount;
        totalSupply -= amount;
        sellReserve -= withdraw;
        require(sellReserve >= 0,"sellReserve need more than 0");
        withdraw /= 1000;
        msg.sender.transfer(withdraw);
        emit OnSell(msg.sender,withdraw,amount);
    }

    /// @notice 可以用这个合约来转移股份
    /// @dev 如果在众筹阶段，是不允许转移股份的
    /// @param to 转给谁，amount 转多少
    function transfer(address to,uint256 amount) public payable isStart() {
        require(amount > 0,"");
        require(!during_crowdfunding,"");
        require(to != address(0),"");
        require(to != msg.sender,"");
        require(balances[msg.sender] >= amount,"");
        balances[msg.sender] -= amount;
        balances[to] += amount;
    }

    /// @notice 投资的项目盈利，用这个接口购买股份
    /// @dev 收入和投资相比，不给某人的账户增加对应的fnd，投资的项目盈利后持续回报能保证之前股价的稳定增长，保证投资者的利益。
    function revenue() public payable isStart() {
        require(msg.value > 0,"value need more 0");
        uint256 invest = msg.value;
        uint256 fndAmount = sqrt(2 * invest * 1000 / slope + totalSupply * totalSupply) - totalSupply;
        totalSupply += fndAmount;
        //存在本合约储备池里的钱
        sellReserve += beta * invest;
        //发给项目池用作发展的钱
        uint256 sendToVote = (1000 - beta) * invest;
        totalSendToVote += sendToVote;
        address(vote).transfer(sendToVote / 1000);
        emit OnRevenue(msg.sender,msg.value,fndAmount);
    }

    /// @notice 锁定某人的股份
    /// @dev 只能允许vote合约调用
    /// @param who 锁定的地址
    function unsafe_lockFnd(address who,uint256 clearingProposalIndex) public returns(bool){
        //调用者必须是vote合约
        require(msg.sender == address(vote), "sender should be vote contract");
        require(balances[who] > 0, "fnd need more than 0");
        lock_balances[clearingProposalIndex][who] += balances[who];
        balances[who] = 0;
        return true;
    }

    /// @notice 解锁某地址的股份
    /// @dev 只能vote合约调用  ??有没有必要判断提议失败与否
    /// @param who 解锁的地址
    function unsafe_unLockFnd(address who,uint256 clearingProposalIndex) public returns(bool){
        //调用者必须是vote合约
        require(msg.sender == address(vote),"sender should be vote contract");
        require(lock_balances[clearingProposalIndex][who] > 0, "lock fnd need more than 0");
        balances[who] += lock_balances[clearingProposalIndex][who];
        lock_balances[clearingProposalIndex][who] = 0;
        return true;
    }

    /// @notice 把要清退的股份分离出储备池
    /// @param clearingShares 清退的股份数量
    function unsafe_clearing(uint256 clearingShares,uint256 clearingProposalIndex)  public returns(bool){
        //调用者必须是vote合约
        require(msg.sender == address(vote),"sender should be vote contract");
        clearingTotalFnd[clearingProposalIndex] = clearingShares;
        clearingValue[clearingProposalIndex] = clearingShares * sellReserve / totalSupply;
        sellReserve -= clearingValue[clearingProposalIndex];
        return true;
    }

    /// @notice 获取清退的钱
    function unsafe_getClearingValue(address payable who,uint256 clearingProposalIndex) public{
        //调用者必须是vote合约
        require(msg.sender == address(vote),"sender should be vote contract");
        uint256 fndAmount = lock_balances[clearingProposalIndex][who];
        uint256 value = fndAmount * clearingValue[clearingProposalIndex] / clearingTotalFnd[clearingProposalIndex] / 1000;
        address(who).transfer(value);
    }
}