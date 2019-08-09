pragma solidity >=0.4.22 <0.6.0;
import "./GovernFundPool.sol";

contract Govern_Proposal_ApplyFund{

    /// @notice 治理资金池合约
    GovernFundPool public governFundPool;

    /// @notice 合约所有者
    address public owner;

    /// @notice 发起提议需要抵押的eth数量（对应成fnd）
    uint256 public deposit = 0.1 ether;

    /// @notice 一个提议有14天的投票窗口期
    uint256 votingPeriodLength = 7 days;

    /// @notice 所有的提议
    Proposal[] public proposalQueue;

    /// @notice 一个提议的结构
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

    /// @notice 申请提议
    event OnApplyProposal(
        uint256 index,
        string proposalName,
        address proposaler,
        address proposalAddress,
        uint256 startTime,
        string detail
    );

    /// @param who 投票人
    /// @param index 提议的序列号
    /// @param voteResult 投什么票
    /// @param shares 有多少股
    event OnVote(
        address who,
        uint256 index,
        uint8 voteResult,
        uint256 shares
    );

    /// @param index 提议的序列号 , pass 是否通过
    event OnProcess(
        uint256 index,
        bool pass
    );

    /// @param index 提议的序列号
    event OnAbort(
        uint256 index
    );

    /// @param index 提议的序列号
    event OnOneTicketRefuse(
        uint256 index
    );

    constructor(GovernFundPool _governFundPool,address _owner) public{
        owner = _owner;
        governFundPool = _governFundPool;
    }

    modifier ownFnd() {
        require(getFndInGovern(msg.sender)>0, "need has shares");
        _;
    }

    /// @notice 查询拥有多少股份币
    /// @param _address 需要查询的地址
    function getFndInGovern(address _address)
    private
    view
    returns(uint256){
        address who = _address;
        if(who == address(0))
            who = msg.sender;
        return governFundPool.getFndInGovernFundPool(who);
    }

    /// @notice 查询总共有多少股份
    function getTotalSupply() private view returns(uint256){
        return governFundPool.getFndTotalSupply();
    }

    /// @notice 管理者重新指定下一个管理者
    function changeOwner(address _address) public{
        require(msg.sender == owner,"limited authority");
        owner = _address;
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
    payable
    ownFnd()
    {
        require(_recipient != address(0),"_recipient cannot be null");
        require(_value>0,"value need more than 0");
        require(_timeConsuming>=0,"_timeConsuming cant less than 0");
        //发起提议的人需要转给本合约一定的gas作为费用奖励处理者
        require(msg.value == proposalFee, "need proposalFee");

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

        //需要锁定1eth的fnd币
        bool r = governFundPool.lock_eth_in(msg.sender,proposal.index,proposal.startTime + votingPeriodLength,deposit);
        require(r,"lock error");

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

    function vote(uint256 proposalIndex,uint8 result,uint256 fndAmount) public ownFnd() {
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
        emit OnVote(msg.sender,1,proposalIndex,result,shares);

        bool r = governFundPool.lock(msg.sender,proposal.index, proposal.startTime + votingPeriodLength,fndAmount);
        require(r,"lock error");
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
        emit OnAbort(proposalIndex,2);
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
        emit OnOneTicketRefuse(proposalIndex,1);
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
        //处理提议的人可以得到一比奖励
        msg.sender.transfer(proposalFee);
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
        emit OnProcess(proposalIndex,1,proposal.pass);
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
        //msg.sender.transfer(canGetMoney);
        governFundPool.sendEthToAddress(proposal.recipient,canGetMoney);
        emit OnGetMoney(proposalIndex,canGetMoney, proposal.tap.totalMoney,now);
    }
}