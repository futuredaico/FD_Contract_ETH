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
    //投票窗口期
    uint256 votingPeriodLength;
    //公示窗口期
    uint256 publicityPeriodLength;

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

    constructor (AppManager _appManager,address _sharesAddress,uint256 _votingPeriodLength,uint256 _publicityPeriodLength)
    public
    FutureDaoApp(_appManager)
    {
        sharesAddress = _sharesAddress;
        votingPeriodLength = _votingPeriodLength;
        publicityPeriodLength = _publicityPeriodLength;
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