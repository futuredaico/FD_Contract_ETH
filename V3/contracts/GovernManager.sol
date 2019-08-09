pragma solidity >=0.4.22 <0.6.0;
import "./GovernFundPool.sol";

contract GovernManager{

    /// @notice 治理资金池合约
    GovernFundPool public governFundPool;

    /// @notice 合约所有者
    address public owner;

    /// @notice 发起提议需要抵押的eth数量（对应成fnd）
    uint256 public deposit = 0.1 ether;

    /// @notice 一个提议有7天的投票窗口期
    uint256 votingPeriodLength = 7 days;

    /// @notice 白名单
    mapping(address=>bool) whiteList;

    /// @notice 所有的提议
    Proposal[] public proposalQueue;

    /// @notice 当前的提议
    Proposal public curProposal;

    /// @notice 一个提议的结构
    struct Proposal{
        uint256 index;//提议的序号
        string proposalName; //提议的名字
        address proposer; //提议人
        address proposalContractAddress;//处理特定协议的合约地址
        uint256 approveVotes; //同意的票数
        uint256 refuseVotes; //否决的票数
        uint256 startTime; //开始的时间
        bool process; //是否已经处理提议
        bool pass;//是否通过
        bool abort;//是否终止
        bool oneTicketRefuse;//是否被一票否决
        mapping(address => enumVoteResult) voteDetails;
        string detail; //提议的描述
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
        address proposalContractAddress,
        uint256 startTime,
        string detail
    );

    /// @param who 投票人
    /// @param index 提议的序列号
    /// @param voteResult 投什么票
    /// @param fndAmount 有多少股
    event OnVote(
        address who,
        uint256 index,
        uint8 voteResult,
        uint256 fndAmount
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

    constructor(GovernFundPool _governFundPool,address _owner,address[] whiteContractAddress) public{
        owner = _owner;
        governFundPool = _governFundPool;
        for(uint256 i = 0;i<whiteContractAddress.length;i++){
            whiteList[whiteContractAddress[i]] = true;
        }
    }

    modifier ownFnd() {
        require(getFndInGovern(msg.sender)>0, "need has fnd");
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

    /// @notice 查询是否在白名单中
    function isWhiteAddress(address _addr) public view returns(bool){
        require(whiteList[_addr] || _addr == address(this),"address is not whiteaddress");
        return true;
    }

    /// @notice 提议增加某种提议
    function applyProposal(
        string memory _proposalName,
        address _proposalContractAddress,
        string memory _detail
    )
    public
    payable
    ownFnd()
    {
        //发起提议的人需要转给本合约一定的gas作为费用奖励处理者
        require(msg.value == 0.1 ether, "need proposalFee");
        //上一个提议必须要已经处理过
        require(curProposal.process == true || curProposal.startTime == 0, "At the same time paragraph only allow to give proposals");

        curProposal = Proposal({
            index : proposalQueue.length,
            proposalName : _proposalName,
            proposer : msg.sender,
            proposalContractAddress : _proposalContractAddress,
            approveVotes : 0,
            refuseVotes : 0,
            startTime : now,
            process : false,
            pass : false,
            abort : false,
            oneTicketRefuse : false,
            detail : _detail
        });


        //需要锁定一定eth的fnd币
        bool r = governFundPool.lock_eth_in(msg.sender,curProposal.index,curProposal.startTime + votingPeriodLength,deposit);
        require(r,"lock error");

        emit OnApplyProposal(
            curProposal.index,
            curProposal.proposalName,
            curProposal.proposer,
            curProposal.proposalContractAddress,
            curProposal.startTime,
            curProposal.detail
        );

        proposalQueue.push(curProposal);
    }

    function vote(uint8 result,uint256 fndAmount) public ownFnd() {
        //提议首先要存在
        require(proposalIndex<proposalQueue.length,"proposal does not exist");
        //投票要在投票期内
        require(now <= curProposal.startTime + votingPeriodLength,"time out");
        //投票的状态是默认（弃权）状态
        require(curProposal.voteDetails[msg.sender] == enumVoteResult.waiver,"Votes have been cast");
        //投票的结果只能是赞成或反对
        require(result == 1||result == 2,"vote result must be less than 3");
        //没有被终止
        require(curProposal.abort == false,"proposal has been aborted");
        //也没有被一票否决
        require(curProposal.oneTicketRefuse == false,"proposal has been oneTicketRefuse");
        //保存投票相关信息
        enumVoteResult voteResult = enumVoteResult(result);
        curProposal.voteDetails[msg.sender] = voteResult;

        bool r = governFundPool.lock(msg.sender,curProposal.index, curProposal.startTime + votingPeriodLength,fndAmount);
        require(r,"lock error");

        if(voteResult == enumVoteResult.approve){
            curProposal.approveVotes = curProposal.approveVotes + fndAmount;
        }
        else{
            curProposal.refuseVotes = curProposal.refuseVotes + fndAmount;
        }
        proposalQueue[curProposal.index] = curProposal;

        emit OnVote(msg.sender,proposalIndex,result,shares);
    }

    /// @notice 终止提议
    function abortProposal() public{
        //提出终止的人必须是发起人
        require(curProposal.proposer == msg.sender,"sender should be proposer");
        //必须还处于有效期内
        require(now <= curProposal.startTime + votingPeriodLength,"time out");
        //没有被一票否决
        require(curProposal.oneTicketRefuse == false,"proposal has been oneTicketRefuse");
        //没有被终止过
        require(curProposal.abort == false,"proposal has been aborted");
        curProposal.abort = true;
        curProposal.process = true;
        proposalQueue[curProposal.index] = curProposal;
        emit OnAbort(curProposal.index);
    }

    /// @notice 一票否决
    /// @dev 只有合约管理者拥有此权限
    /// @param proposalIndex 提议的序号
    function oneTicketRefuseProposal() public{
        //只有管理员有一票否决权
        require(owner == msg.sender,"sender should be owner");
        //没有被终止
        require(curProposal.abort == false,"proposal has been aborted");
        //也没有被一票否决
        require(curProposal.oneTicketRefuse == false,"proposal has been oneTicketRefuse");

        curProposal.oneTicketRefuse = true;
        curProposal.process = true;
        proposalQueue[curProposal.index] = curProposal;
        emit OnOneTicketRefuse(curProposal.index);
    }

        /// @notice 处理提议
    /// @param proposalIndex 提议的序号
    function process() public {
        //投票已经过了投票权
        require(now > curProposal.startTime + votingPeriodLength,"it's within the expiry date");
        //没有被处理过
        require(curProposal.process == false,"proposal has been process");
        //没有被终止
        require(curProposal.abort == false,"proposal has been aborted");
        //也没有被一票否决
        require(curProposal.oneTicketRefuse == false,"proposal has been oneTicketRefuse");
        curProposal.process = true;
        //处理提议的人可以得到一比奖励
        msg.sender.transfer(0.1 ether);
        //根据票行得到是否通过提案
        if(curProposal.refuseVotes * 100 / getTotalSupply >= 30){
            curProposal.pass = false;
        }
        else if(curProposal.approveVotes > curProposal.refuseVotes){
            whiteList[curProposal.proposalAddress] = true;
            curProposal.pass = true;
        }
        else{
            curProposal.pass = false;
        }
        proposalQueue[curProposal.index] = curProposal;
        emit OnProcess(curProposal.index,curProposal.pass);
    }

    /// @notice 解锁锁定的fnd
    function free(uint256 proposalIndex) public{
        
    }
}