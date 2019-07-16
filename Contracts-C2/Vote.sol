pragma solidity >=0.4.22 <0.6.0;
import "./FundPool.sol";

/// @title 自治合约
/// @author viko
/// @notice 发起提议，投票，处理提议等
contract N_Vote{
    /// @notice 合约的拥有者
    address owner;

    /// @notice 与此合约绑定的资金池的合约
    N_FundPool fundPool;

    /// @notice 一个提议有14天的投票窗口期
    uint votingPeriodLength = 14 days;

    /// @notice 清算提议的投票窗口期
    uint clearingVotingPeriodLehgth = 7 days;

    /// @notice 所有的基础提议
    Proposal[] proposalQueue;

    /// @notice 所有的清算提议
    ClearingProposal[] clearingProposalQueue;

    /// @notice 清算需要的退款
    mapping(uint256=>uint256) clearingValue;

    /// @notice 所有清退的退款总额
    uint256 totalClearingVlaue;

    /// @notice 当前的清算提议  同时期应该只允许一个清算提议
    ClearingProposal public cur_clearingProposal;

    /// @notice 一个基础提议的结构
    struct Proposal{
        uint256 index;//提议的序号
        string proposalName; //提议的名字
        address proposer; //提议人
        uint256 approveVotes; //同意的票数
        uint256 refuseVotes; //否决的票数
        uint256 startTime; //开始的时间
        address recipient; //提议给谁gas
        uint256 value; //提议所申请的钱
        uint256 timeConsuming; //耗时 单位是天，例如30天，那就意味着所申请的钱需要这么多天才能领取完
        bool process; //是否已经处理提议
        bool pass; //是否通过
        bool abort;//是否终止
        bool oneTicketRefuse;//是否被一票否决
        mapping(address => enumVoteResult) voteDetails;
        string detail; //提议的描述
        Tap tap;
    }

    /// @notice 清算提议
    struct ClearingProposal{
        uint256 index;
        mapping(address => uint256) clearingList;//同意人的列表
        uint256 startTime;//开始的时间
        address proposer;//清算的发起者
        uint256 totalShares;//同意的总股份
        bool pass; //是否通过
        bool process; //是否已经处理过
    }

    /// @notice 给某人钱，从什么时候开始，到什么时候，多少钱
    struct Tap{
        uint256 startTime;
        uint256 endTime;
        uint256 totalMoney;
    }

    /// @notice 投票的结果
    enum enumVoteResult {
        waiver,
        approve,
        refuse
    }

    /* events */
    /// @param 提议的序列号，提议的名称，提议者，开始提议的时间，资金接收者，资金数额，资金接受总耗时,详情
    event OnApplyProposal(
        uint256 index,
        string proposalName,
        address proposer,
        uint256 startTime,
        address recipient,
        uint256 value,
        uint256 timeConsuming,
        string detail
    );

    /// @param 投票人 提议的序列号，投什么票，有多少股
    event OnVote(
        address who,
        uint256 index,
        uint8 voteResult,
        uint256 shares
    );

    /// @param 提议的序列号，是否通过
    event OnProcess(
        uint256 index,
        bool pass
    );

    /// @param 提议的序列号
    event OnAbort(
        uint256 index
    );

    /// @param 提议的序列号
    event OnOneTicketRefuse(
        uint256 index
    );

    /// @param 提议的序列号，获取的钱，还剩多少钱，领取的时间
    event OnGetMoney(
        uint256 index,
        uint256 getMoney,
        uint256 totalMoney,
        uint256 getTime
    );

    /// @param 发起者 开始的时间
    event OnApplyClearingProposal(
        uint256 index,
        address proposer,
        uint256 startTime
    );

    /// @param 同意的地址 所持有的股数
    event OnVoteClearingProposal(
        uint256 index,
        address who,
        uint256 shares
    );

    /// @param 提议的发起人 提议开始的时间 提议获得的总票数 提议是否通过
    event OnProcessClearingProposal(
        uint256 index,
        address proposer,
        uint256 startTime,
        uint256 totalShares,
        bool pass
    );

    modifier ownShares() {
        require(getSharesOf(msg.sender)>0, "need has shares");
        _;
    }

    constructor(address _owner,N_FundPool _fundPool) public{
        owner = _owner;
        fundPool = _fundPool;
    }

    /// @notice 获取总共有多少提案
    function getLengthOfProposalQueue() public view returns(uint256){
        return proposalQueue.length;
    }

    /// @notice 根据index获取提案基础信息
    /// @param proposalIndex 提议的序号
    function getProposalInfoByIndex(uint256 proposalIndex) public view returns(
        string memory,
        address,
        uint256,
        address,
        uint256,
        uint256,
        string memory details
    )
    {
        Proposal memory proposal = proposalQueue[proposalIndex];
        return(
            proposal.proposalName,
            proposal.proposer,
            proposal.startTime,
            proposal.recipient,
            proposal.value,
            proposal.timeConsuming,
            proposal.detail
            );
    }

    /// @notice 根据index获取提案的投票状态
    /// @param proposalIndex 提议的序号
    function getProposalStateByIndex(uint256 proposalIndex) public view returns(
        uint256,
        uint256,
        bool,
        bool,
        bool,
        bool
    )
    {
        Proposal memory proposal = proposalQueue[proposalIndex];
        return(proposal.approveVotes,proposal.refuseVotes,proposal.process,proposal.pass,proposal.abort,proposal.oneTicketRefuse);
    }

    /// @notice 查看提案资金领取情况
    /// @param proposalIndex 提议的序号
    function getTapByIndex(uint256 proposalIndex) public view returns(
        uint256 startTime,
        uint256 endTime,
        uint256 money
    )
    {
        Proposal memory proposal = proposalQueue[proposalIndex];
        startTime = proposal.tap.startTime;
        endTime = proposal.tap.endTime;
        money = proposal.tap.totalMoney;
    }

    /// @notice 查询拥有多少股份币
    /// @param _address 需要查询的地址
    function getSharesOf(address _address)
    public
    view
    returns(uint256){
        address who = _address;
        if(who == address(0))
            who = msg.sender;
        return fundPool.balances(who);
    }

    /// @notice 申请提议
    /// @param _name 提议的名字，_recipient 提议给谁钱，_value 给多少钱，_timeConsuming 多久给完，_detail 提议的详情
    function applyProposal(
        string memory _name,
        address _recipient,
        uint256 _value,
        uint256 _timeConsuming,
        string memory _detail
    )
        public
        ownShares
    {
        require(_recipient != address(0),"_recipient cannot be null");
        require(_value>0,"value need more than 0");
        require(_timeConsuming>=0,"_timeConsuming cant less than 0");
        //发起提议的人需要有一定的股份
        uint256 shares = getSharesOf(msg.sender);
        require(shares > 0,"shares need more than 0");
        Proposal memory proposal = Proposal({
            index : proposalQueue.length,
            proposalName : _name,
            proposer : msg.sender,
            approveVotes : 0,
            refuseVotes : 0,
            startTime : now,
            recipient : _recipient,
            value : _value,
            timeConsuming : _timeConsuming,
            process : false,
            pass : false,
            abort : false,
            oneTicketRefuse : false,
            detail : _detail,
            tap : Tap({startTime:0,endTime:0,totalMoney:0})
        });
        emit OnApplyProposal(
            proposal.index,
            proposal.proposalName,
            proposal.proposer,
            proposal.startTime,
            proposal.recipient,
            proposal.value,
            proposal.timeConsuming,
            proposal.detail
        );
        proposalQueue.push(proposal);
    }

    /// @notice 终止提议
    /// @param proposalIndex 提议的序号
    function abortProposal(uint256 proposalIndex) public ownShares(){
        //提议首先要存在
        require(proposalIndex<proposalQueue.length,"proposal does not exist");
        Proposal storage proposal = proposalQueue[proposalIndex];
        //提出终止的人必须是发起人
        require(proposal.proposer == msg.sender,"sender should be proposer");
        //必须还处于有效期内
        require(now <= proposal.startTime + votingPeriodLength,"time out");
        //没有被一票否决
        require(proposal.oneTicketRefuse == false,"proposal has been oneTicketRefuse");
        //没有被终止过
        require(proposal.abort == false,"proposal has been aborted");

        proposal.abort = true;
        emit OnAbort(proposalIndex);
    }

    /// @notice 一票否决
    /// @dev 只有合约管理者拥有此权限
    /// @param proposalIndex 提议的序号
    function oneTicketRefuseProposal(uint256 proposalIndex) public ownShares() {
        //只有管理员有一票否决权
        require(owner == msg.sender,"sender should be owner");
        //提议首先要存在
        require(proposalIndex<proposalQueue.length,"proposal does not exist");
        Proposal storage proposal = proposalQueue[proposalIndex];
        //没有被终止
        require(proposal.abort == false,"proposal has been aborted");
        //也没有被一票否决
        require(proposal.oneTicketRefuse == false,"proposal has been oneTicketRefuse");

        proposal.oneTicketRefuse = true;
        emit OnOneTicketRefuse(proposalIndex);
    }

    /// @notice 投票
    /// @param proposalIndex 提议的序号，result 对提议的态度
    function vote(uint256 proposalIndex,uint8 result) public ownShares() {
        //提议首先要存在
        require(proposalIndex<proposalQueue.length,"proposal does not exist");
        Proposal storage proposal = proposalQueue[proposalIndex];
        //投票要在投票期内
        require(now <= proposal.startTime + votingPeriodLength,"time out");
        //投票的状态是默认（弃权）状态
        require(proposal.voteDetails[msg.sender] == enumVoteResult.waiver,"Votes have been cast");
        //投票的结果只能是赞成或反对
        require(result == 1||result == 2,"vote result must be less than 3");
        //没有被终止
        require(proposal.abort == false,"proposal has been aborted");
        //也没有被一票否决
        require(proposal.oneTicketRefuse == false,"proposal has been oneTicketRefuse");
        //保存投票相关信息
        enumVoteResult voteResult = enumVoteResult(result);
        proposal.voteDetails[msg.sender] = voteResult;
        //增加总票型
        uint256 shares = getSharesOf(msg.sender);
        //需要有票
        require(shares > 0,"shares need more 0");
        if(voteResult == enumVoteResult.approve){
            proposal.approveVotes = proposal.approveVotes + shares;
        }
        else{
            proposal.refuseVotes = proposal.refuseVotes + shares;
        }
        emit OnVote(msg.sender,proposalIndex,result,shares);
    }

    /// @notice 处理提议
    /// @param proposalIndex 提议的序号
    function process(uint256 proposalIndex) public {
        //提议首先要存在
        require(proposalIndex<proposalQueue.length,"proposal does not exist");
        Proposal storage proposal = proposalQueue[proposalIndex];
        //投票已经过了投票权
        require(now > proposal.startTime + votingPeriodLength,"it's within the expiry date");
        //没有被处理过
        require(proposal.process == false,"proposal has been process");
        //没有被终止
        require(proposal.abort == false,"proposal has been aborted");
        //也没有被一票否决
        require(proposal.oneTicketRefuse == false,"proposal has been oneTicketRefuse");
        proposal.process = true;

        //根据票行得到是否通过提案
        if(proposal.approveVotes>proposal.refuseVotes){
            proposal.pass = true;
            // 通过了提案就给接收人划一笔钱
            Tap memory tap = Tap({
                startTime : now,
                endTime : now + proposal.timeConsuming * 1 days,
                totalMoney : proposal.value
            });
            proposal.tap = tap;
        }
        emit OnProcess(proposalIndex,proposal.pass);
    }

    /// @notice 领取提议通过的钱
    /// @param proposalIndex 提议的序号
    function getMoney(uint256 proposalIndex) public {
        //提议首先要存在
        require(proposalIndex<proposalQueue.length,"proposal does not exist");
        Proposal storage proposal = proposalQueue[proposalIndex];
        //提议是通过的
        require(proposal.pass == true,"proposal does not pass");
        //领钱的人是提议中允许的人
        require(msg.sender == proposal.recipient,"sender must be recipient");
        Tap memory tap = proposal.tap;
        require(tap.totalMoney > 0,"no money");
        //领取钱
        uint256 times = (now - tap.startTime) / 1 days;
        uint256 allTimes = (tap.endTime - tap.startTime) / 1 days;
        uint256 canGetMoney = allTimes == 0?tap.totalMoney: tap.totalMoney / allTimes * times;
        require(canGetMoney < address(this).balance,"not enough money");
        proposal.tap.startTime = tap.startTime + (times * 1 days);
        proposal.tap.totalMoney -= canGetMoney;
        require(tap.totalMoney >= 0,"tap.totalCanMoney cant less than 0");
        msg.sender.transfer(canGetMoney);
        emit OnGetMoney(proposalIndex,canGetMoney, proposal.tap.totalMoney,now);
    }

    /// @notice 发起清算提议
    /// @dev 股东都可以发起清算提议
    function applyClearingProposal() public {
        uint256 shares = getSharesOf(msg.sender);
        require(shares > 0,"shares need more than 0");
        //只能允许一个清算提议
        require(cur_clearingProposal.proposer == address(0),"Only one proposal is allowed");
        cur_clearingProposal = ClearingProposal({
            index : clearingProposalQueue.length,
            proposer : msg.sender,
            totalShares : 0,
            startTime : now,
            pass : false,
            process :false
        });
        clearingProposalQueue.push(cur_clearingProposal);
        emit OnApplyClearingProposal(cur_clearingProposal.index,cur_clearingProposal.proposer,cur_clearingProposal.startTime);
    }

    /// @notice 参与清算提议
    function voteClearingProposal() public{
        uint256 shares = getSharesOf(msg.sender);
        require(shares > 0,"shares need more than 0");
        //需要在7天内
        require(now <= cur_clearingProposal.startTime + clearingVotingPeriodLehgth,"time out");
        cur_clearingProposal.clearingList[msg.sender] += shares;
        cur_clearingProposal.totalShares += shares;
        //这里要告知fundpool合约需要锁定股东的股份
        fundPool.call(bytes4(keccak256("unsafe_lockFnd(address,uint256)")),msg.sender,cur_clearingProposal.index);
        emit OnVoteClearingProposal(cur_clearingProposal.index,msg.sender,shares);
    }

    /// @notice 处理提议
    function processClearingProposal() public{
        //提议要超过7天
        require(now > cur_clearingProposal.startTime + clearingVotingPeriodLehgth,"it's within the expiry date");
        require(cur_clearingProposal.process == false, "needs proposals have not been addressed");
        //获取当前所有fnd的数量
        uint256 totalFnd = fundPool.totalSupply;
        uint hold = cur_clearingProposal.totalShares * 1000 / totalFnd;
        if(hold < 300){
            cur_clearingProposal.pass = false;
        }
        else{
            cur_clearingProposal.pass = true;
            //需要清退的总额
            uint256 value = cur_clearingProposal.totalShares * 1000 * address(this).balance / totalFnd / 1000 + 1;
            clearingValue[cur_clearingProposal.index] = value;
            totalClearingVlaue+=value;
            //去fundpool合约中算钱
            fundPool.call(bytes4(keccak256("unsafe_clearing(address,uint256)")),cur_clearingProposal.totalShares,cur_clearingProposal.index);
        }
        //标示已经处理
        cur_clearingProposal.process = true;

        emit OnProcessClearingProposal(
            cur_clearingProposal.index,
            cur_clearingProposal.proposer,
            cur_clearingProposal.startTime,
            cur_clearingProposal.totalShares,
            cur_clearingProposal.pass
        );

        //当前的清算要置空
        cur_clearingProposal = ClearingProposal({
            index : 0,
            proposer : address(0),
            totalShares : 0,
            startTime : 0,
            pass : false,
            process : false
        });
    }

    /// @notice 解锁锁定的股份
    function unLockShares(uint256 clearingProposalIndex) public {
        ClearingProposal storage clearingProposal = clearingProposalQueue[clearingProposalIndex];
        require(clearingProposal.clearingList[msg.sender] > 0,"need voted");
        require(clearingProposal.pass = false,"need proposal failed");
        require(now > clearingProposal.startTime + clearingVotingPeriodLehgth, "it's within the expiry date");
        require(cur_clearingProposal.process == false, "needs proposals have not been addressed");
        fundPool.call(bytes4(keccak256("unsafe_unLockFnd(address,uint256)")),msg.sender,clearingProposalIndex);
        clearingProposal.clearingList[msg.sender] = 0;
    }

    /// @notice 领取清算的钱
    function getClearingValue(uint256 clearingProposalIndex) public {
        ClearingProposal storage clearingProposal = clearingProposalQueue[clearingProposalIndex];
        require(clearingProposal.clearingList[msg.sender] > 0,"need voted");
        require(clearingProposal.pass = true,"need proposal pass");
        require(now > clearingProposal.startTime + clearingVotingPeriodLehgth, "it's within the expiry date");
        require(cur_clearingProposal.process == false, "needs proposals have not been addressed");
        fundPool.call(bytes4(keccak256("unsafe_getClearingValue(address,uint256)")),msg.sender,clearingProposalIndex);
        uint256 shares = clearingProposal.clearingList[msg.sender];
        uint256 totalShares = clearingProposal.totalShares;
        uint256 totalValue = clearingValue[clearingProposalIndex];
        uint256 value = shares * totalValue * 1000 / totalShares / 1000;
        msg.sender.transfer(value);
        totalClearingVlaue -= value;
        clearingProposal.clearingList[msg.sender] = 0;
    }

    function() external payable{
    }
}