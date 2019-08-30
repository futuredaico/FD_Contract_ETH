pragma solidity >=0.4.22 <0.6.0;

import "../apps/FutureDaoApp.sol";
import "../Interface/IGovernShareManager.sol";

contract VoteApp is FutureDaoApp {
    /// @notice 一个提议有14天的投票窗口期
    uint256 votingPeriodLength = 7 days;

    /// @notice 发起提议需要抵押的eth数量（对应成fnd）
    uint256 public deposit = 0.1 ether;

    /// @notice 发起提议的人需要给的手续费，用来奖励结算的人
    uint256 public proposalFee = 0.1 ether;

    /// @notice 投票的结果
    enum enumVoteResult {
        waiver,
        approve,
        refuse
    }

    /// @notice 获取可以投票的股份数
    function getFdtInGovern(address _addr) public returns(uint256){
        return IGovernShareManager(appManager.getGovernShareManager()).getFdtInGovern(_addr);
    }

    /// @notice 获取全部的票数
    function getFdtTotalSupply() public returns(uint256){
        return IGovernShareManager(appManager.getGovernShareManager()).getFtdTotalSupply();
    }
}