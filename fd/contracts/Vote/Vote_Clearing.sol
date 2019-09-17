pragma solidity >=0.4.22 <0.6.0;

import "./VoteApp.sol";
import "../clearing/ClearingFundPool.sol";

contract Govern_Proposal_ApplyFund is VoteApp{

    /// @notice 当前的清算提议  同时期应该只允许一个清算提议
    ClearingProposal public cur_clearingProposal;
    
    /// @notice 所有的清算提议
    ClearingProposal[] clearingProposalQueue;

    /// @notice 清算提议
    struct ClearingProposal{
        uint256 index;
        mapping(address => uint256) clearingList;//同意人的列表
        uint256 startTime;//开始的时间
        address proposer;//清算的发起者
        uint256 totalFndAmount;//同意的总票数
        address payable address_clearingFundPool;
        bool pass; //是否通过
        bool process; //是否已经处理过
    }

    /// @notice 申请提议
    event OnApplyClearingProposal(
        uint256 index,
        address proposaler,
        address payable address_clearingFundPool,
        uint256 startTime
    );

    /// @param who 投票人
    /// @param index 提议的序列号
    /// @param voteResult 投什么票
    /// @param fndAmount 有多少股
    event OnVoteClearingProposal(
        address who,
        uint256 index,
        uint256 fndAmount
    );

    /// @param index 提议的序列号 , pass 是否通过
    event OnProcessClearingProposal(
        uint256 index,
        bool pass
    );

    constructor(AppManager _appManager) public{
        appManager = _appManager;
    }

    modifier ownFnd() {
        require(getFdtInGovern(msg.sender)>0, "need has shares");
        _;
    }

    /// @notice 发起清算提议
    /// @dev 股东都可以发起清算提议
    function applyClearingProposal() public payable ownFnd(){
        //只能允许一个清算提议
        require(cur_clearingProposal.proposer == address(0),"Only one proposal is allowed");
        //发起提议的人需要转给本合约一定的gas作为费用奖励处理者
        require(msg.value >= proposalFee + deposit, "need proposalFee");

        ClearingFundPool _clearingFundPool = new ClearingFundPool(appManager.getGovernShareManager(),appManager.getFdToken());

        cur_clearingProposal = ClearingProposal({
            index : clearingProposalQueue.length,
            proposer : msg.sender,
            totalFndAmount : 0,
            startTime : now,
            pass : false,
            process :false,
            address_clearingFundPool : address(_clearingFundPool)
        });

        clearingProposalQueue.push(cur_clearingProposal);

        emit OnApplyClearingProposal(
            cur_clearingProposal.index,
            cur_clearingProposal.proposer,
            address(_clearingFundPool),
            cur_clearingProposal.startTime
        );
    }

    /// @notice 参与清算提议
    function voteClearingProposal() public ownFnd(){
        uint256 fndInGovern = getFdtInGovern(msg.sender);
        require(fndInGovern > 0,"fndInGovern need more than 0");
        //需要在7天内
        require(now <= cur_clearingProposal.startTime + votingPeriodLength,"time out");


        bool r = IGovernShareManager(appManager.getGovernShareManager())
        .clearingFdt(cur_clearingProposal.address_clearingFundPool,msg.sender,fndInGovern);
        require(r,"lock error");

        cur_clearingProposal.clearingList[msg.sender] += fndInGovern;
        cur_clearingProposal.totalFndAmount += fndInGovern;

        emit OnVoteClearingProposal(msg.sender,cur_clearingProposal.index,fndInGovern);
    }

    /// @notice 处理提议
    function processClearingProposal() public{
        //提议要超过7天
        require(now > cur_clearingProposal.startTime + votingPeriodLength,"it's within the expiry date");
        require(cur_clearingProposal.process == false, "needs proposals have not been addressed");
        //获取当前所有fnd的数量
        uint256 totalFnd = getFdtTotalSupply();
        uint hold = cur_clearingProposal.totalFndAmount * (10 ** 9) / totalFnd;
        if(hold < (3*(10**8))){
            cur_clearingProposal.pass = false;
        }
        else{
            cur_clearingProposal.pass = true;
            //需要清退的总额
            //去fundpool合约中算钱
            bool r = IGovernShareManager(appManager.getGovernShareManager()).clearing(cur_clearingProposal.address_clearingFundPool,hold);
            require(r, "call failed");
        }
        //标示已经处理
        cur_clearingProposal.process = true;
        //给处理人一比奖励
        msg.sender.transfer(proposalFee);
        //通知
        emit OnProcessClearingProposal(
            cur_clearingProposal.index,
            cur_clearingProposal.pass
        );

        //当前的清算要置空
        cur_clearingProposal = ClearingProposal({
            index : 0,
            proposer : address(0),
            address_clearingFundPool : address(0),
            totalFndAmount : 0,
            startTime : 0,
            pass : false,
            process : false
        });
    }
}