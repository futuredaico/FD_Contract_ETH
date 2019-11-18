pragma solidity >=0.4.22 <0.6.0;

import "./VoteApp.sol";
import "../Interface/IDateTime.sol";
import "../Interface/IGovernShareManager.sol";

contract Vote_ApplySharesA is VoteApp{

    bytes32 public constant Vote_ApplyFund_OneTicketRefuseProposal = keccak256("Vote_ApplyFund_OneTicketRefuseProposal");
    bytes32 public constant Vote_ApplyFund_oneTicketStopTap = keccak256("Vote_ApplyFund_oneTicketStopTap");

    /// @notice 所有的提议
    Proposal[] private proposalQueue;

    address payable private govern;

    /// @notice 一个提议的结构
    struct Proposal{
        uint256 index;//提议的序号
        string proposalName; //提议的名字
        address payable proposer; //提议人
        uint256 sharesAmount; //索要sharesA的数量
        uint256 assetValue; //给予的资产数
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
        string proposalName,
        address payable proposaler,
        uint256 sharesAmount, //索要sharesA的数量
        uint256 assetValue, //给予的资产数
        uint256 votingStartTime,
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

    event OnPass(
        uint256 index
    );

    /// @param index 提议的序列号 , pass 是否通过
    event OnProcess(
        uint256 index
    );

    event OnGetAssetBack(
        uint256 index,
        uint256 assetValue
    );

    constructor(AppManager _appManager,address payable _governAddress,address _sharesAddress,uint256 _voteRatio,uint256 _approveRatio)
    VoteApp(_appManager,_sharesAddress,_voteRatio,_approveRatio)
    public
    {
        govern = _governAddress;
    }

    /////////////
    /// 查询的方法
    /////////////
    //查询总共提议的数量
    function getProposalQueueLength() public view returns(uint256){
        return proposalQueue.length;
    }

    /// @notice 查询某一个index对应的提议的信息
    function getProposalInfoByIndex(uint256 _proposalIndex)
    public
    view
    returns(string memory _proposalName,address _proposer,uint256 _sharesAmount,uint256 _assetValue,string memory _detail)
    {
        uint256 queueIndex = proposalIndexToQueueIndex(_proposalIndex);
        Proposal storage proposal = proposalQueue[queueIndex];
        _proposalName = proposal.proposalName;
        _proposer = proposal.proposer;
        _detail = proposal.detail;
        _sharesAmount = proposal.sharesAmount;
        _assetValue = proposal.assetValue;
    }

    ///查询某个协议的投票状态
    function getProposalStateByIndex(uint256 _proposalIndex)
    public
    view
    returns(uint256 _approveVotes,uint256 _refuseVotes,bool _process,bool _pass,uint256 _votingStartTime,uint256 _publicityStartTime)
    {
        uint256 queueIndex = proposalIndexToQueueIndex(_proposalIndex);
        Proposal storage proposal = proposalQueue[queueIndex];
        _approveVotes = proposal.approveVotes;
        _refuseVotes = proposal.refuseVotes;
        _process = proposal.process;
        _pass = proposal.pass;
        _votingStartTime = proposal.votingStartTime;
        _publicityStartTime = proposal.publicityStartTime;
    }

    /// @notice 申请提议
    /// @param _name 提议的名字，_detail 提议的详情
    function applyProposal(
        string memory _name,
        uint256 _sharesAmount,
        uint256 _assetValue,
        string memory _detail
    )
    public
    payable
    ownShares()
    {
        transferFrom(msg.sender,address(this),_assetValue + proposalFee + deposit);

        Proposal memory proposal = Proposal({
            index : proposalQueue.length + 1,
            proposalName : _name,
            proposer : msg.sender,
            sharesAmount : _sharesAmount,
            assetValue : _assetValue,
            approveVotes : 0,
            refuseVotes : 0,
            process : false,
            pass : false,
            votingStartTime : now,
            publicityStartTime : 0,
            detail : _detail
        });

        emit OnApplyProposal(
            proposal.index,
            proposal.proposalName,
            proposal.proposer,
            proposal.sharesAmount,
            proposal.assetValue,
            proposal.votingStartTime,
            proposal.detail
        );
        proposalQueue.push(proposal);
    }

    function vote(uint256 _proposalIndex,uint8 result,uint256 sharesAmount) public ownShares() {
        //提议首先要存在
        uint256 queueIndex = proposalIndexToQueueIndex(_proposalIndex);
        Proposal storage proposal = proposalQueue[queueIndex];
        //投票要在投票期内
        require(now < proposal.votingStartTime + votingPeriodLength,"time out");
        //投票的结果只能是赞成或反对
        require(result == 1||result == 2,"vote result must be less than 3");
        //投票的状态是默认（弃权）状态
        require(proposal.voteDetails[msg.sender].result == enumVoteResult.waiver,"Votes have been cast");
        //投票的数量不能超过持有的A股数量
        require(getBalanceOf(msg.sender) > sharesAmount,"not enough sharesA");
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
        bool r;
        (r,,) = canPass(proposal.approveVotes,proposal.refuseVotes);
        //判断提议是否可以通过
        if(r){//已经满足要求进入公示期
            proposal.pass = true;
            proposal.publicityStartTime = now;
            emit OnPass(proposal.index);
        }
    }

    /// @notice 处理提议
    /// @param _proposalIndex 提议的序号
    function process(uint256 _proposalIndex) public {
        uint256 queueIndex = proposalIndexToQueueIndex(_proposalIndex);
        Proposal storage proposal = proposalQueue[queueIndex];
        //投票已经过了公示期
        require(now > proposal.votingStartTime + votingPeriodLength + publicityPeriodLength,"Should exceed the publicity period");
        //提议应该是通过的
        require(proposal.pass == true,"proposal need pass");
        //没有被处理过
        require(proposal.process == false,"proposal has been process");
        proposal.process = true;

        emit OnProcess(_proposalIndex);

        ////这里是给提议人增发A股的逻辑
        bool r = IGovernShareManager(govern).enter(proposal.proposer,proposal.sharesAmount);
        require(r,"enter faild");
        //如果有捐赠，则将捐赠也赋予govern
        if (proposal.assetValue > 0) {
            transfer(address(govern),proposal.assetValue);
        }
        //处理提议的人可以得到一比奖励
        transfer(msg.sender,proposalFee);
        //发起人拿回押金
        transfer(proposal.proposer,deposit);
    }

    /// @notice 如果提议没有通过 那么需要拿回抵押的财产
    function getAssetBack(uint256 _proposalIndex) public {
        uint256 queueIndex = proposalIndexToQueueIndex(_proposalIndex);
        Proposal storage proposal = proposalQueue[queueIndex];
        //已经过了投票期，并且没有达到要求
        require(now >= proposal.votingStartTime + votingPeriodLength && proposal.pass == false,"Still on the ballot or passed");
        //有钱可以退
        require(proposal.assetValue > 0,"No money to back");
        //把钱退给提议人
        transfer(proposal.proposer,proposal.assetValue);
        emit OnGetAssetBack(_proposalIndex,proposal.assetValue);
        proposal.assetValue = 0;
        //处理提议的人可以得到一比奖励
        transfer(msg.sender,proposalFee);
        //发起人拿回押金
        transfer(proposal.proposer,deposit);
    }


    function proposalIndexToQueueIndex(uint256 _proposalIndex) private view returns(uint256){
        //提议首先要存在
        require(_proposalIndex <= proposalQueue.length && _proposalIndex>0,"proposal does not exist");
        return _proposalIndex - 1;
    }

    function() external payable{
    }
}