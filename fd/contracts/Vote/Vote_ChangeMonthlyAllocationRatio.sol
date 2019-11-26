pragma solidity >=0.4.22 <0.6.0;

import "./VoteApp.sol";
import "../Tap/Tap.sol";
import "../Interface/IDateTime.sol";
import "../Interface/ITradeFundPool.sol";

contract Vote_ChangeMonthlyAllocation is VoteApp{

    /// @notice 所有的提议
    Proposal[] private proposalQueue;

    mapping(bytes32=>uint256) counter;

    address private tradeAddress;

    /// @notice 一个提议的结构
    struct Proposal{
        uint256 index;//提议的序号
        address payable proposer; //提议人
        uint256 ratio;
        uint256 minValue;
        uint256 maxValue;
        uint256 approveVotes; //同意的票数
        uint256 refuseVotes; //否决的票数
        bool process; //是否已经处理提议
        bool pass; //是否通过
        uint256 votingStartTime;//提议的开始时间
        uint256 publicityStartTime;//公示的开始时间
        mapping(address => VoteInfo) voteDetails;
        string detail; //提议的描述
    }

    /// @notice 申请提议
    event OnApplyProposal(
        uint256 index,
        address payable proposaler,
        uint256 ratio,
        uint256 minValue,
        uint256 maxValue,
        uint256 votingStartTime
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

    /// @param index 提议的序列号
    event OnPass(uint256 index);

    /// @param index 提议的序列号
    event OnProcess(
        uint256 index
    );

    constructor(AppManager _appManager,address _sharesAddress,address _tradeAddress,uint256 _votingPeriodLength,uint256 _publicityPeriodLength)
    VoteApp(_appManager,_sharesAddress,_votingPeriodLength,_publicityPeriodLength)
    public
    {
        sharesAddress = _sharesAddress;
        tradeAddress = _tradeAddress;
    }

    /////////////
    /// 查询的方法
    /////////////
    //查询总共提议的数量
    function getProposalQueueLength() public view returns(uint256){
        return proposalQueue.length;
    }

    ///查询某一个index对应的提议的信息()
    function getProposalBaseInfoByIndex(uint256 _proposalIndex)
    public
    view
    returns(address _proposer,string memory _detail)
    {
        uint256 queueIndex = proposalIndexToQueueIndex(_proposalIndex);
        Proposal storage proposal = proposalQueue[queueIndex];
        _proposer = proposal.proposer;
        _detail = proposal.detail;
    }

    ///查询某个协议的投票状态
    function getProposalStateByIndex(uint256 _proposalIndex)
    public
    view
    returns(uint256 _approveVotes,uint256 _refuseVotes,bool _process,bool _pass)
    {
        uint256 queueIndex = proposalIndexToQueueIndex(_proposalIndex);
        Proposal storage proposal = proposalQueue[queueIndex];
        _approveVotes = proposal.approveVotes;
        _refuseVotes = proposal.refuseVotes;
        _process = proposal.process;
        _pass = proposal.pass;
    }

    /// @notice 申请提议
    /// @param _detail 提议的详情
    function applyProposal(
        uint256 _ratio,
        uint256 _minValue,
        uint256 _maxValue,
        string memory _detail
    )
    public
    payable
    ownShares()
    {
        transferF(msg.sender,address(this),proposalFee + deposit);

        Proposal memory proposal = Proposal({
            index : proposalQueue.length + 1,
            proposer : msg.sender,
            approveVotes : 0,
            refuseVotes : 0,
            process : false,
            pass : false,
            ratio : _ratio,
            minValue : _minValue,
            maxValue : _maxValue,
            detail : _detail,
            votingStartTime : now,
            publicityStartTime : 0
        });
        proposalQueue.push(proposal);

        emit OnApplyProposal(
            proposal.index,
            proposal.proposer,
            proposal.ratio,
            proposal.minValue,
            proposal.maxValue,
            proposal.votingStartTime
        );
    }

    function vote(uint256 _proposalIndex,uint8 result,uint256 sharesAmount) public ownShares() {
        //提议首先要存在
        uint256 queueIndex = proposalIndexToQueueIndex(_proposalIndex);
        Proposal storage proposal = proposalQueue[queueIndex];
        //投票要在投票期内
        require(now < proposal.votingStartTime + votingPeriodLength,"time out");
        //投票的结果只能是赞成或反对
        require(result == 1||result == 2,"vote result must be less than 3");
        //提议还没有被通过
        require(proposal.pass == false,"proposal cant pass");
        //投票的状态是默认（弃权）状态
        require(proposal.voteDetails[msg.sender].result == enumVoteResult.waiver,"Votes have been cast");
        //投票的人要拥有这么多的票数
        uint256 balance = IERC20(sharesAddress).balanceOf(msg.sender);
        require(balance >= sharesAmount,"not enough shares");
        //保存投票相关信息
        enumVoteResult voteResult = enumVoteResult(result);
        proposal.voteDetails[msg.sender].result = voteResult;
        proposal.voteDetails[msg.sender].sharesAmount = sharesAmount;

        if(voteResult == enumVoteResult.approve){
            proposal.approveVotes = proposal.approveVotes + sharesAmount;
        }
        else{
            proposal.refuseVotes = proposal.refuseVotes + sharesAmount;
        }

        emit OnVote(msg.sender,_proposalIndex,result,sharesAmount);
    }

    /// @notice 处理提议
    /// @param _proposalIndex 提议的序号
    function process(uint256 _proposalIndex) public {
        uint256 queueIndex = proposalIndexToQueueIndex(_proposalIndex);
        Proposal storage proposal = proposalQueue[queueIndex];
        //投票已经过了公示期
        require(now >= proposal.votingStartTime + votingPeriodLength + publicityPeriodLength,"Should exceed the publicity period");
        //没有被处理过
        require(proposal.process == false,"proposal has been process");
        proposal.process = true;

        emit OnProcess(_proposalIndex);

        if (proposal.approveVotes >= proposal.refuseVotes) {
            proposal.pass = true;
            ////这里是修改ratio的逻辑
            ITradeFundPool(tradeAddress).changeRatio(proposal.ratio,proposal.minValue,proposal.maxValue);
            emit OnPass(proposal.index);
        }

        //处理提议的人可以得到一比奖励
        transferM(msg.sender,proposalFee);
        //发起人拿回押金
        transferM(proposal.proposer,deposit);
    }

    function proposalIndexToQueueIndex(uint256 _proposalIndex) private view returns(uint256){
        //提议首先要存在
        require(_proposalIndex <= proposalQueue.length && _proposalIndex>0,"proposal does not exist");
        return _proposalIndex - 1;
    }

    function() external payable{
    }
}