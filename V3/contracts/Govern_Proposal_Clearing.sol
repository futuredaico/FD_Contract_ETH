pragma solidity >=0.4.22 <0.6.0;
import "./GovernFundPool.sol";

contract Govern_Proposal_ApplyFund{

    /// @notice 治理资金池合约
    GovernFundPool public governFundPool;

    /// @notice 合约所有者
    address public owner;

    /// @notice 发起提议需要抵押的eth数量（对应成fnd）
    uint256 public deposit = 0.1 ether;

    /// @notice 一个提议有3天的投票窗口期
    uint256 votingPeriodLength = 3 days;

    /// @notice 所有的提议
    Proposal[] public proposalQueue;

    /// @notice 所有的清算提议
    ClearingProposal[] clearingProposalQueue;

    /// @notice 当前的清算提议  同时期应该只允许一个清算提议
    ClearingProposal public cur_clearingProposal;

    /// @notice 清算提议
    struct ClearingProposal{
        uint256 index;
        mapping(address => uint256) clearingList;//同意人的列表
        uint256 startTime;//开始的时间
        address proposer;//清算的发起者
        uint256 totalFndAmount;//同意的总票数
        bool pass; //是否通过
        bool process; //是否已经处理过
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

    /// @notice 发起清算提议
    /// @dev 股东都可以发起清算提议
    function applyClearingProposal() public payable ownFnd(){
        //只能允许一个清算提议
        require(cur_clearingProposal.proposer == address(0),"Only one proposal is allowed");
        cur_clearingProposal = ClearingProposal({
            index : clearingProposalQueue.length,
            proposer : msg.sender,
            totalFndAmount : 0,
            startTime : now,
            pass : false,
            process :false
        });
        //需要缴纳手续费
        require(msg.value == proposalFee, "need proposalFee");

        //需要锁定一定eth的fnd币
        bool r = governFundPool.lock_eth_in(msg.sender,proposal.index,proposal.startTime + votingPeriodLength,deposit);
        require(r,"lock error");

        clearingProposalQueue.push(cur_clearingProposal);
        emit OnApplyClearingProposal(cur_clearingProposal.index,cur_clearingProposal.proposer,cur_clearingProposal.startTime);
    }

    /// @notice 参与清算提议
    function voteClearingProposal() public ownFnd(){
        uint256 fndInGovern = getFndInGovern(msg.sender);
        require(fndInGovern > 0,"fndInGovern need more than 0");
        //需要在7天内
        require(now <= cur_clearingProposal.startTime + clearingVotingPeriodLehgth,"time out");
        cur_clearingProposal.clearingList[msg.sender] += fndInGovern;
        cur_clearingProposal.totalFndAmount += fndInGovern;

        bool r = governFundPool.lock(msg.sender,proposal.index, proposal.startTime + votingPeriodLength,fndAmount);
        require(r,"lock error");

        //这里要告知fundpool合约需要锁定股东的股份
        (bool success,) = address(fundPool).call(abi.encodeWithSignature("unsafe_lockFnd(address,uint256)",msg.sender,cur_clearingProposal.index));
        require(success, "call failed");
        emit OnVoteClearingProposal(cur_clearingProposal.index,msg.sender,fndInGovern);
    }

    /// @notice 处理提议
    function processClearingProposal() public{
        //提议要超过7天
        require(now > cur_clearingProposal.startTime + clearingVotingPeriodLehgth,"it's within the expiry date");
        require(cur_clearingProposal.process == false, "needs proposals have not been addressed");
        //获取当前所有fnd的数量
        uint256 totalFnd = fundPool.totalSupply();
        uint hold = cur_clearingProposal.totalFndAmount * 1000 / totalFnd;
        if(hold < 300){
            cur_clearingProposal.pass = false;
        }
        else{
            cur_clearingProposal.pass = true;
            //需要清退的总额
            uint256 value = cur_clearingProposal.totalFndAmount * 1000 * address(this).balance / totalFnd / 1000 + 1;
            clearingValue[cur_clearingProposal.index] = value;
            totalClearingVlaue+=value;
            //去fundpool合约中算钱
            (bool success,) = address(fundPool).call(abi.encodeWithSignature("unsafe_clearing(address,uint256)",cur_clearingProposal.totalFndAmount,cur_clearingProposal.index));
            require(success, "call failed");
        }
        //标示已经处理
        cur_clearingProposal.process = true;
        //给处理人一比奖励
        msg.sender.transfer(proposalFee);
        //通知
        emit OnProcessClearingProposal(
            cur_clearingProposal.index,
            cur_clearingProposal.proposer,
            cur_clearingProposal.startTime,
            cur_clearingProposal.totalFndAmount,
            cur_clearingProposal.pass
        );

        //当前的清算要置空
        cur_clearingProposal = ClearingProposal({
            index : 0,
            proposer : address(0),
            totalFndAmount : 0,
            startTime : 0,
            pass : false,
            process : false
        });
    }
}