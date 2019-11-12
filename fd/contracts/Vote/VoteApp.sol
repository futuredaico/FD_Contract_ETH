pragma solidity >=0.4.22 <0.6.0;

import "../apps/FutureDaoApp.sol";
import "../Interface/IERC20.sol";
import "../lib/SafeMath.sol";

contract VoteApp is FutureDaoApp {
    using SafeMath for uint256;

    /// @notice 一个提议有7天的投票窗口期
    uint256 votingPeriodLength = 5 minutes; //测试用
    /// @notice 公示期
    uint256 publicityPeriodLength = 9 minutes;

    //uint256 votingPeriodLength = 5 days;
    //uint256 publicityPeriodLength = 9 days;


    /// @notice 发起提议需要抵押的eth数量（对应成fnd）
    uint256 public deposit = 0.1 ether;

    /// @notice 发起提议的人需要给的手续费，用来奖励结算的人
    uint256 public proposalFee = 0.1 ether;

    //投票采用的哪个股份币
    address public sharesHash = address(0);

    //要求投票的人数占比
    uint256 public voteRatio = 0;  //全都乘以1000  300意味着 30%
    //要求同意的人数占比
    uint256 public approveRatio = 0;

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

    /// @notice 获取可以投票的股份数
    function getBalanceOf(address _addr) public view returns(uint256){
        return IERC20(sharesHash).balanceOf(_addr);
    }

    /// @notice 获取全部的票数
    function getTotalSupply() public view returns(uint256){
        return IERC20(sharesHash).totalSupply();
    }
}