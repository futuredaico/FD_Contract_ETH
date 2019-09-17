pragma solidity >=0.4.22 <0.6.0;

import "./VoteApp.sol";
import "../Tap/Tap.sol";
import "../Interface/IDateTime.sol";

contract Vote_ApplyFund is VoteApp{

    bytes32 public constant Vote_ApplyFund_OneTicketRefuseProposal = keccak256("Vote_ApplyFund_OneTicketRefuseProposal");
    bytes32 public constant Vote_ApplyFund_oneTicketStopTap = keccak256("Vote_ApplyFund_oneTicketStopTap");

    /// @notice 所有的提议
    Proposal[] private proposalQueue;

    ///一天最多的提议数量
    uint256 maxProposalOneDay = 5;

    mapping(bytes32=>uint256) counter;

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
        bool abandon;//是否被弃用，当发起重审并通过时会被置为true
        bool oneTicketRefuse;//是否被一票否决
        mapping(address => enumVoteResult) voteDetails;
        string detail; //提议的描述
        address payable address_tap; //水龙头的地址
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

    /// @param index 提议的序列号
    event OnOneTicketStopTap(
        uint256 index
    );

    constructor(AppManager _appManager) FutureDaoApp(_appManager) public{
    }

    modifier ownFdt() {
        require(getFdtInGovern(msg.sender)>0, "need has shares");
        _;
    }

    /////////////
    /// 查询的方法
    /////////////
    //查询总共提议的数量
    function getProposalQueueLength() public view returns(uint256){
        return proposalQueue.length;
    }

    ///查询今天已经有几个议题了
    function getAmountOfProposalToday() public view returns(uint256){
        bytes32 b32 = getTimeHash();
        return counter[b32];
    }

    ///查询某一个index对应的提议的信息()
    function getProposalBaseInfoByIndex(uint256 _proposalIndex)
    public
    view
    returns(string memory _proposalName,address _proposer,string memory _detail,address payable _address_tap)
    {
        uint256 queueIndex = proposalIndexToQueueIndex(_proposalIndex);
        Proposal storage proposal = proposalQueue[queueIndex];
        _proposalName = proposal.proposalName;
        _proposer = proposal.proposer;
        _detail = proposal.detail;
        _address_tap = proposal.address_tap;
    }

    ///查询某个协议的投票状态
    function getProposalStateByIndex(uint256 _proposalIndex)
    public
    view
    returns(uint256 _approveVotes,uint256 _refuseVotes,bool _process,bool _pass,bool _abort,bool _abandon,bool _oneTicketRefuse)
    {
        uint256 queueIndex = proposalIndexToQueueIndex(_proposalIndex);
        Proposal storage proposal = proposalQueue[queueIndex];
        _approveVotes = proposal.approveVotes;
        _refuseVotes = proposal.refuseVotes;
        _process = proposal.process;
        _pass = proposal.pass;
        _abort = proposal.abort;
        _abandon = proposal.abandon;
        _oneTicketRefuse = proposal.oneTicketRefuse;
    }
    //查询某个协议的水龙头情况
    function getProposalTapByIndex(uint256 _proposalIndex)
    public
    view
    returns(uint256 _startTime,address payable _recipient,uint256 _value,uint256 _timeConsuming)
    {
        uint256 queueIndex = proposalIndexToQueueIndex(_proposalIndex);
        Proposal storage proposal = proposalQueue[queueIndex];
        _startTime = proposal.sTap.startTime;
        _recipient = proposal.sTap.recipient;
        _value = proposal.sTap.value;
        _timeConsuming = proposal.sTap.timeConsuming;
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
        require(_value >= 0,"value need more than 0");
        require(_timeConsuming>=0,"_timeConsuming cant less than 0");
        //发起提议的人需要转给本合约一定的gas作为费用奖励处理者
        require(msg.value >= proposalFee + deposit, "need proposalFee");
        //当前天的提议数量看看是多少
        bytes32 b32 = getTimeHash();
        require(counter[b32] < maxProposalOneDay,"Beyond the maxProposalOneDay");

        STap memory _sTap = STap({
            startTime : now,
            recipient : _recipient,
            value : _value,
            timeConsuming : _timeConsuming
        });

        Proposal memory proposal = Proposal({
            index : proposalQueue.length + 1,
            proposalName : _name,
            proposer : msg.sender,
            approveVotes : 0,
            refuseVotes : 0,
            sTap : _sTap,
            process : false,
            pass : false,
            abort : false,
            oneTicketRefuse : false,
            abandon : false,
            detail : _detail,
            address_tap : address(0)
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
        counter[b32] = counter[b32].add(1);
    }

    function vote(uint256 _proposalIndex,uint8 result,uint256 FdtAmount) public ownFdt() {
        //提议首先要存在
        uint256 queueIndex = proposalIndexToQueueIndex(_proposalIndex);
        Proposal storage proposal = proposalQueue[queueIndex];
        //投票要在投票期内
        require(now <= proposal.sTap.startTime + votingPeriodLength,"time out");
        //投票的结果只能是赞成或反对
        require(result == 1||result == 2,"vote result must be less than 3");
        //投票的状态是默认（弃权）状态
        require(proposal.voteDetails[msg.sender] == enumVoteResult.waiver || proposal.voteDetails[msg.sender] == enumVoteResult(result),"Votes have been cast");
        //没有被终止
        require(proposal.abort == false,"proposal has been aborted");
        //也没有被一票否决
        require(proposal.oneTicketRefuse == false,"proposal has been oneTicketRefuse");
        //保存投票相关信息
        enumVoteResult voteResult = enumVoteResult(result);
        proposal.voteDetails[msg.sender] = voteResult;
        if(voteResult == enumVoteResult.approve){
            proposal.approveVotes = proposal.approveVotes + FdtAmount;
        }
        else{
            proposal.refuseVotes = proposal.refuseVotes + FdtAmount;
        }

        bool r = IGovernShareManager(appManager.getGovernShareManager()).lock(
            msg.sender,
            proposal.index,
            proposal.sTap.startTime + votingPeriodLength,
            FdtAmount
        );
        require(r,"lock error");

        emit OnVote(msg.sender,_proposalIndex,result,FdtAmount);
    }

    /// @notice 终止提议
    /// @param _proposalIndex 提议的序号
    function abortProposal(uint256 _proposalIndex) public{
        uint256 queueIndex = proposalIndexToQueueIndex(_proposalIndex);
        Proposal storage proposal = proposalQueue[queueIndex];
        //提出终止的人必须是发起人
        require(proposal.proposer == msg.sender,"sender should be proposer");
        //必须还处于有效期内
        require(now <= proposal.sTap.startTime + votingPeriodLength,"time out");
        //没有被一票否决
        require(proposal.oneTicketRefuse == false,"proposal has been oneTicketRefuse");
        //没有被终止过
        require(proposal.abort == false,"proposal has been aborted");
        proposal.abort = true;
        emit OnAbort(_proposalIndex);
        bytes32 b32 = getTimeHash(proposal.sTap.startTime);
        counter[b32] = counter[b32].sub(1);
    }

    /// @notice 一票否决
    /// @dev 只有合约管理者拥有此权限
    /// @param _proposalIndex 提议的序号
    function oneTicketRefuseProposal(uint256 _proposalIndex) public auth(Vote_ApplyFund_OneTicketRefuseProposal){
        uint256 queueIndex = proposalIndexToQueueIndex(_proposalIndex);
        Proposal storage proposal = proposalQueue[queueIndex];
        //没有被终止
        require(proposal.abort == false,"proposal has been aborted");
        //也没有被一票否决
        require(proposal.oneTicketRefuse == false,"proposal has been oneTicketRefuse");

        proposal.oneTicketRefuse = true;
        emit OnOneTicketRefuse(_proposalIndex);
        bytes32 b32 = getTimeHash(proposal.sTap.startTime);
        counter[b32] = counter[b32].sub(1);
    }

    /// @notice 一票停发
    /// @dev 有权限要求
    /// @param _proposalIndex 提议的序号
    function oneTicketStopTap(uint256 _proposalIndex) public auth(Vote_ApplyFund_oneTicketStopTap){
        uint256 queueIndex = proposalIndexToQueueIndex(_proposalIndex);
        Proposal storage retrial_proposal = proposalQueue[queueIndex];
        require(retrial_proposal.abandon == false,"proposal has been abandon");
        Tap address_retrial_tap = Tap(retrial_proposal.address_tap);
        address_retrial_tap.GetMoneyBackToFund();
        retrial_proposal.abandon = true;
        emit OnOneTicketStopTap(_proposalIndex);
    }

    /// @notice 处理提议
    /// @param _proposalIndex 提议的序号
    function process(uint256 _proposalIndex) public {
        uint256 queueIndex = proposalIndexToQueueIndex(_proposalIndex);
        Proposal storage proposal = proposalQueue[queueIndex];
        //投票已经过了投票期 处于公示期
        require(now > proposal.sTap.startTime + votingPeriodLength && now < proposal.sTap.startTime + votingPeriodLength + publicityPeriodLength,"it's within the expiry date");
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
            if(proposal.sTap.value>0){
                // 通过了提案就给接收人划一笔钱
                Tap tap = new Tap(address(this),appManager.getTradeFundPool(),proposal.sTap.recipient,now,(now.add(proposal.sTap.timeConsuming)).mul(1 days),proposal.sTap.value);
                IGovernShareManager(appManager.getGovernShareManager()).sendEth(address(tap),proposal.sTap.value);
                proposal.address_tap = address(tap);
            }
        }
        emit OnProcess(_proposalIndex,proposal.pass);
        bytes32 b32 = getTimeHash(proposal.sTap.startTime);
        counter[b32] = counter[b32].sub(1);
    }

    function freeFdt(uint256[] memory _proposalIndexs) public {
        for(uint256 i = 0;i<_proposalIndexs.length;i++){
            uint256 _proposalIndex = _proposalIndexs[i];
            require(_proposalIndex <= proposalQueue.length && _proposalIndex>0,"proposal does not exist");
            Proposal storage proposal = proposalQueue[_proposalIndex];
            //需要提议是 已经处理或者被一票否决或者被撤销
            require(proposal.process == true || proposal.abort == true || proposal.oneTicketRefuse == true,"proposal need process");
            IGovernShareManager(appManager.getGovernShareManager()).free(msg.sender,_proposalIndex,proposal.sTap.startTime + votingPeriodLength);
        }
    }

    function proposalIndexToQueueIndex(uint256 _proposalIndex) private view returns(uint256){
        //提议首先要存在
        require(_proposalIndex <= proposalQueue.length && _proposalIndex>0,"proposal does not exist");
        return _proposalIndex - 1;
    }

    function getTimeHash() private view returns(bytes32){
        IDateTime dateTime = IDateTime(appManager.getDateTime());
        uint16 year = dateTime.getYear(now);
        uint8 month = dateTime.getMonth(now);
        uint8 day = dateTime.getDay(now);
        return keccak256(abi.encodePacked(year,month,day));
    }

    function getTimeHash(uint256 timestamp) private view returns(bytes32){
        IDateTime dateTime = IDateTime(appManager.getDateTime());
        uint16 year = dateTime.getYear(timestamp);
        uint8 month = dateTime.getMonth(timestamp);
        uint8 day = dateTime.getDay(timestamp);
        return keccak256(abi.encodePacked(year,month,day));
    }

    function() external payable{
    }
}