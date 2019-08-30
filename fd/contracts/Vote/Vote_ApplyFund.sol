pragma solidity >=0.4.22 <0.6.0;

import "./VoteApp.sol";
import "../Tap/Tap.sol";

contract Vote_ApplyFund is VoteApp{

    bytes32 public constant Vote_ApplyFund_OneTicketRefuseProposal = keccak256("Vote_ApplyFund_OneTicketRefuseProposal");

    /// @notice 所有的提议
    Proposal[] private proposalQueue;

    /// @notice 一个提议的结构
    struct Proposal{
        uint256 index;//提议的序号
        string proposalName; //提议的名字
        address proposer; //提议人
        uint256 approveVotes; //同意的票数
        uint256 refuseVotes; //否决的票数
        STap sTap;
        bool process; //是否已经处理提议
        bool pass; //是否通过
        bool abort;//是否终止
        bool oneTicketRefuse;//是否被一票否决
        mapping(address => enumVoteResult) voteDetails;
        string detail; //提议的描述
    }

    struct STap {
        uint256 startTime; //开始的时间
        address payable recipient; //提议给谁gas
        uint256 value; //提议所申请的钱
        uint256 timeConsuming; //耗时 单位是天，例如30天，那就意味着所申请的钱需要这么多天才能领取完
    }

    /// @notice 申请提议
    event OnApplyProposal(
        uint256 index,
        string proposalName,
        address proposaler,
        uint256 startTime,
        address recipient,
        uint256 value,
        uint256 timeConsuming,
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

    constructor(AppManager _appManager) public{
        appManager = _appManager;
    }

    modifier ownFdt() {
        require(getFdtInGovern(msg.sender)>0, "need has shares");
        _;
    }

    /// @notice 申请提议
    /// @param _name 提议的名字，_recipient 提议给谁钱，_value 给多少钱，_timeConsuming 多久给完，_detail 提议的详情
    function applyProposal(
        string memory _name,
        address payable _recipient,
        uint256 _value,
        uint256 _timeConsuming,
        string memory _detail
    )
    public
    payable
    ownFdt()
    {
        require(_recipient != address(0),"_recipient cannot be null");
        require(_value>0,"value need more than 0");
        require(_timeConsuming>=0,"_timeConsuming cant less than 0");
        //发起提议的人需要转给本合约一定的gas作为费用奖励处理者
        require(msg.value >= proposalFee + deposit, "need proposalFee");
        STap memory _sTap = STap({
            startTime : now,
            recipient : _recipient,
            value : _value,
            timeConsuming : _timeConsuming
        });
        Proposal memory proposal = Proposal({
            index : proposalQueue.length,
            proposalName : _name,
            proposer : msg.sender,
            approveVotes : 0,
            refuseVotes : 0,
            sTap : _sTap,
            process : false,
            pass : false,
            abort : false,
            oneTicketRefuse : false,
            detail : _detail
        });

        emit OnApplyProposal(
            proposal.index,
            proposal.proposalName,
            proposal.proposer,
            proposal.sTap.startTime,
            proposal.sTap.recipient,
            proposal.sTap.value,
            proposal.sTap.timeConsuming,
            proposal.detail
        );
        proposalQueue.push(proposal);
    }

    function vote(uint256 proposalIndex,uint8 result,uint256 FdtAmount) public ownFdt() {
        //提议首先要存在
        require(proposalIndex<proposalQueue.length,"proposal does not exist");
        Proposal storage proposal = proposalQueue[proposalIndex];
        //投票要在投票期内
        require(now <= proposal.sTap.startTime + votingPeriodLength,"time out");
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
        uint256 shares = getFdtInGovern(msg.sender);

        if(voteResult == enumVoteResult.approve){
            proposal.approveVotes = proposal.approveVotes + shares;
        }
        else{
            proposal.refuseVotes = proposal.refuseVotes + shares;
        }
        emit OnVote(msg.sender,proposalIndex,result,shares);

        bool r = IGovernShareManager(appManager.getGovernShareManager()).lock(
            msg.sender,
            proposal.index,
            proposal.sTap.startTime + votingPeriodLength,
            FdtAmount
        );
        require(r,"lock error");
    }

    /// @notice 终止提议
    /// @param proposalIndex 提议的序号
    function abortProposal(uint256 proposalIndex) public{
        //提议首先要存在
        require(proposalIndex<proposalQueue.length,"proposal does not exist");
        Proposal storage proposal = proposalQueue[proposalIndex];
        //提出终止的人必须是发起人
        require(proposal.proposer == msg.sender,"sender should be proposer");
        //必须还处于有效期内
        require(now <= proposal.sTap.startTime + votingPeriodLength,"time out");
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
    function oneTicketRefuseProposal(uint256 proposalIndex) public auth(Vote_ApplyFund_OneTicketRefuseProposal){
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

    /// @notice 处理提议
    /// @param proposalIndex 提议的序号
    function process(uint256 proposalIndex) public {
        //提议首先要存在
        require(proposalIndex<proposalQueue.length,"proposal does not exist");
        Proposal storage proposal = proposalQueue[proposalIndex];
        //投票已经过了投票权
        require(now > proposal.sTap.startTime + votingPeriodLength,"it's within the expiry date");
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
            Tap tap = new Tap(proposal.sTap.recipient,now,(now.add(proposal.sTap.timeConsuming)).mul(1 days),proposal.sTap.value);
            IGovernShareManager(appManager.getGovernShareManager()).sendEth(address(tap),proposal.sTap.value);
        }
        emit OnProcess(proposalIndex,proposal.pass);
    }
}