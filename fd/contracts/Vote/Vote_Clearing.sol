pragma solidity >=0.4.22 <0.6.0;

import "./VoteApp.sol";
import "../clearing/ClearingFundPool.sol";
import "../Interface/ITradeFundPool.sol";

contract Vote_Clearing is VoteApp{

    /// @notice 当前的清算提议  同时期应该只允许一个清算提议
    ClearingProposal public cur_clearingProposal;

    /// @notice 所有的清算提议
    ClearingProposal[] clearingProposalQueue;

    address public tradeAddress;

    /// @notice 清算提议
    struct ClearingProposal{
        uint256 index;
        mapping(address => uint256) clearingList;//同意人的列表
        uint256 startTime;//开始的时间
        address proposer;//清算的发起者
        uint256 totalSharesAmount;//同意的总票数
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
        uint256 sharesAmount
    );

    /// @param index 提议的序列号 , pass 是否通过
    event OnProcessClearingProposal(
        uint256 index,
        bool pass
    );

    constructor(AppManager _appManager,address _sharesAddress,address _tradeAddress,uint256 _voteRatio,uint256 _approveRatio)
    VoteApp(_appManager,_sharesAddress,_voteRatio,_approveRatio)
    public
    {
        tradeAddress = _tradeAddress;
    }

    /// @notice 发起清算提议
    /// @dev 股东都可以发起清算提议
    function applyClearingProposal() public payable ownShares(){
        //只能允许一个清算提议
        require(cur_clearingProposal.proposer == address(0),"Only one proposal is allowed");
        //发起提议的人需要转给本合约一定的费用奖励处理者
        transferFrom(msg.sender, address(this), proposalFee + deposit);

        ClearingFundPool _clearingFundPool = new ClearingFundPool(address(this),appManager.getAssetAddress());

        cur_clearingProposal = ClearingProposal({
            index : clearingProposalQueue.length,
            proposer : msg.sender,
            totalSharesAmount : 0,
            startTime : now,
            pass : false,
            process :false,
            address_clearingFundPool : address(_clearingFundPool)
        });

        emit OnApplyClearingProposal(
            cur_clearingProposal.index,
            cur_clearingProposal.proposer,
            address(_clearingFundPool),
            cur_clearingProposal.startTime
        );
    }

    /// @notice 参与清算提议
    function voteClearingProposal(uint256 _amount) public ownFdt(){
        //需要在投票期间
        require(now <= cur_clearingProposal.startTime + votingPeriodLength,"time out");
        //将投票的股份转移到本合约
        bool r = IERC20(sharesAddress).transferFrom(msg.sender,address(this),_amount);
        require(r, "transferFrom error");

        cur_clearingProposal.clearingList[msg.sender] += _amount;
        cur_clearingProposal.totalFndAmount += _amount;

        ClearingFundPool(cur_clearingProposal.address_clearingFundPool).register(msg.sender,_amount);

        emit OnVoteClearingProposal(msg.sender,cur_clearingProposal.index,_amount);
    }

    /// @notice 处理提议
    function processClearingProposal() public {
        //已经过了投票期了
        require(now > cur_clearingProposal.startTime + votingPeriodLength,"it's within the expiry date");
        require(cur_clearingProposal.process == false,"needs proposals have not been addressed");
        (bool r,uint256 voteRatio_1000,) = canPass(cur_clearingProposal.totalSharesAmount, 0);
        if(r){
            cur_clearingProposal.pass = true;
            ITradeFundPool(tradeAddress).clearing(cur_clearingProposal.address_clearingFundPool,voteRatio_1000);
        }
        else{
            cur_clearingProposal.pass = false;
        }
        //标示已经处理
        cur_clearingProposal.process = true;
        clearingProposalQueue.push(cur_clearingProposal);

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