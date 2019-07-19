pragma solidity >=0.4.22 <0.6.0;

import "./FundPool.sol";
contract Vote{
    //一个提议的结构
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

    struct Tap{
        uint256 startTime;
        uint256 endTime;
        uint256 totalMoney;
    }

    uint votingPeriodLenght = 14 days;

    //投票的结果
    enum enumVoteResult {waiver, approve, refuse}
    address private owner;
    FundPool fundPool;
    Proposal[] proposalQueue;

    /* events */
    event OnApplyProposal(
        uint256 index,
        string proposalName,
        address proposer,
        uint256 startTime,
        address recipient,
        uint256 value,
        uint256 timeConsuming,
        string detail
    );//提议的序列号，提议的名称，提议者，开始提议的时间，资金接收者，资金数额，资金接受总耗时,详情

    event OnVote(uint256 index,uint8 voteResult,uint256 shares);//提议的序列号，投什么票，有多少股

    event OnProcess(uint256 index,bool pass); //提议的序列号，是否通过

    event OnAbort(uint256 index); // 提议的序列号

    event OnOneTicketRefuse(uint256 index); //提议的序列号

    event OnGetMoney(uint256 index,uint256 getMoney,uint256 totalMoney,uint256 getTime); //提议的序列号，获取的钱，还剩多少钱，领取的时间

    modifier ownShares() {
        require(getSharesOf(msg.sender)>0, "need has shares");
        _;
    }

    constructor(address _owner,FundPool _fundPool) public{
        owner = _owner;
        fundPool = _fundPool;
    }
    //获取总共有多少提案
    function getLengthOfProposalQueue() public view returns(uint256){
        return proposalQueue.length;
    }

    //根据index获取提案基础信息
    function getProposalInfoByIndex(uint256 proposalIndex)
    public
    view
    returns(string memory , address , uint256 ,address ,uint256 ,uint256 ,string memory details) {
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
    //根据index获取提案的投票状态
    function getProposalStateByIndex(uint256 proposalIndex) public view  returns(uint256,uint256,bool,bool,bool,bool) {
        Proposal memory proposal = proposalQueue[proposalIndex];
        return(proposal.approveVotes,proposal.refuseVotes,proposal.process,proposal.pass,proposal.abort,proposal.oneTicketRefuse);
    }

    //查看提案资金领取情况
    function getTapByIndex(uint256 proposalIndex) public view  returns(uint256 startTime , uint256 endTime,uint256 money) {
        Proposal memory proposal = proposalQueue[proposalIndex];
        startTime = proposal.tap.startTime;
        endTime = proposal.tap.endTime;
        money = proposal.tap.totalMoney;
    }

    //查询拥有多少股份币
    function getSharesOf(address _address)
    public
    view
    returns(uint256){
        address who = _address;
        if(who == address(0))
            who = msg.sender;
        return fundPool.balances(who);
    }

    //申请提议
    function applyProposal(string memory _name,address _recipient,uint256 _value,uint256 _timeConsuming,string memory _detail)
    public
    ownShares()
    {
        require(_recipient != address(0),"_recipient cannot be null");
        require(_value>0,"value need more than 0");
        require(_timeConsuming>=0,"_timeConsuming cant less than 0");

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

    //终止提议
    function abortProposal(uint256 proposalIndex) public ownShares(){
        //提议首先要存在
        require(proposalIndex<proposalQueue.length,"proposal does not exist");
        Proposal storage proposal = proposalQueue[proposalIndex];
        //提出终止的人必须是发起人
        require(proposal.proposer == msg.sender,"sender should be proposer");
        //必须还处于有效期内
        require(now <= proposal.startTime + votingPeriodLenght,"time out");
        //没有被一票否决
        require(proposal.oneTicketRefuse == false,"proposal has been oneTicketRefuse");
        //没有被终止过
        require(proposal.abort == false,"proposal has been aborted");

        proposal.abort = true;
        emit OnAbort(proposalIndex);
    }

    //一票否决
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

    //投票
    function vote(uint256 proposalIndex,uint8 result) public ownShares() {
        //提议首先要存在
        require(proposalIndex<proposalQueue.length,"proposal does not exist");
        Proposal storage proposal = proposalQueue[proposalIndex];
        //投票要在投票期内
        require(now <= proposal.startTime + votingPeriodLenght,"time out");
        //投票的状态是默认（弃权）状态
        require(proposal.voteDetails[msg.sender] == enumVoteResult.waiver,"Votes have been cast");
        //投票的结果只能是赞成或反对
        require(result == 1 || result == 2,"vote result must be less than 3");
        //没有被终止
        require(proposal.abort == false,"proposal has been aborted");
        //也没有被一票否决
        require(proposal.oneTicketRefuse == false,"proposal has been oneTicketRefuse");

        //保存投票相关信息
        enumVoteResult voteResult = enumVoteResult(result);
        proposal.voteDetails[msg.sender] = voteResult;
        //增加总票型
        uint256 shares = getSharesOf(msg.sender);
        if(voteResult == enumVoteResult.approve){
            proposal.approveVotes = proposal.approveVotes + shares;
        }
        else{
            proposal.refuseVotes = proposal.refuseVotes + shares;
        }
        emit OnVote(proposalIndex,result,shares);
    }

    //处理提议
    function process(uint256 proposalIndex) public {
        //提议首先要存在
        require(proposalIndex<proposalQueue.length,"proposal does not exist");
        Proposal storage proposal = proposalQueue[proposalIndex];
        //投票已经过了投票权
        require(now > proposal.startTime + votingPeriodLenght,"time out");
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

    //领取提议通过的钱
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
        uint256 canGetMoney = allTimes == 0 ? tap.totalMoney : tap.totalMoney / allTimes * times;
        require(canGetMoney < address(this).balance,"not enough money");
        proposal.tap.startTime = tap.startTime + (times * 1 days);
        proposal.tap.totalMoney -= canGetMoney;
        require(tap.totalMoney >= 0,"tap.totalCanMoney cant less than 0");
        msg.sender.transfer(canGetMoney);
        emit OnGetMoney(proposalIndex,canGetMoney, proposal.tap.totalMoney,now);
    }

    function() external payable{
    }
}