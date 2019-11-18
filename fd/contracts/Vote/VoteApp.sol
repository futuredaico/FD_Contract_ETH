pragma solidity >=0.4.22 <0.6.0;

import "../apps/FutureDaoApp.sol";
import "../Interface/IERC20.sol";
import "../lib/SafeMath.sol";

contract VoteApp is FutureDaoApp {
    using SafeMath for uint256;

    struct VoteInfo{
        uint256 sharesAmount;
        enumVoteResult result;
    }

    /// @notice 一个提议有7天的投票窗口期
    uint256 votingPeriodLength = 5 minutes; //测试用
    /// @notice 公示期
    uint256 publicityPeriodLength = 9 minutes;

    //uint256 votingPeriodLength = 5 days;
    //uint256 publicityPeriodLength = 9 days;

    /// @notice 发起提议需要抵押的
    uint256 public deposit;

    /// @notice 发起提议的人需要给的手续费，用来奖励结算的人
    uint256 public proposalFee;

    //投票采用的哪个股份币
    address public sharesAddress = address(0);

    //要求投票的人数占比
    uint256 public voteRatio = 0;  //全都乘以1000  300意味着 30%
    //要求同意的人数占比
    uint256 public approveRatio = 0;
    //要求最低投票占总数比 乘以了1000   例如 5% 就是50
    uint256 public voteRatio_1000;
    // 要求投票的票数中  投赞成的比例
    uint256 public approveRatio_1000;

    /// @notice 投票的结果
    enum enumVoteResult {
        waiver,
        approve,
        refuse
    }

    modifier ownShares() {
        require(getBalanceOf(msg.sender)>0, "need has shares");
        _;
    }

    constructor (AppManager _appManager,address _sharesAddress,uint256 _voteRatio_1000,uint256 _approveRatio_1000)
    public
    FutureDaoApp(_appManager)
    {
        sharesAddress = _sharesAddress;
        voteRatio_1000 = _voteRatio_1000;
        approveRatio_1000 = _approveRatio_1000;
    }

    function canPass(uint256 approveVotes,uint256 refuseVotes) public view returns(bool r,uint256 _voteRatio_1000,uint256 _approveRatio_1000){
        uint256 totalVotes = approveVotes.add(refuseVotes);
        _voteRatio_1000 = totalVotes.mul(1000).div(getTotalSupply());
        _approveRatio_1000 = approveVotes.mul(1000).div(totalVotes);
        if (voteRatio < voteRatio_1000) {
            r = false;
        }
        if (approveRatio < approveRatio_1000) {
            r = false;
        }
        r = true;
    }

    /// @notice 获取可以投票的股份数
    function getBalanceOf(address _addr) public view returns(uint256){
        return IERC20(sharesAddress).balanceOf(_addr);
    }

    /// @notice 获取全部的票数
    function getTotalSupply() public view returns(uint256){
        return IERC20(sharesAddress).totalSupply();
    }
}