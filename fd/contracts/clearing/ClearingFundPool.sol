pragma solidity >=0.4.22 <0.6.0;

import "../lib/SafeMath.sol";
import "../Own/Own.sol";
import "../Interface/IERC20.sol";

contract ClearingFundPool is Own {
    using SafeMath for uint256;

    mapping(address=>clearingInfo) public map_clearingInfo;

    enumVoteResult public clearingResult = enumVoteResult.waiver;

    uint256 public totalShares;

    address public assetAddress;

    address public owner;

    struct clearingInfo{
        uint256 sharesAmount;
        bool isGet;
    }

    /// @notice 投票的结果
    enum enumVoteResult {
        waiver,
        approve,
        refuse
    }

    constructor(address _owner,address _assetAddress) public{
        owner = _owner;
        assetAddress = _assetAddress;
    }

    function register(address account,uint256 amount) public isOwner(msg.sender) returns(bool){
        map_clearingInfo[account].sharesAmount += amount;
        totalShares += amount;
        return true;
    }

    function clear(address payable who) public{
        require(clearingResult == enumVoteResult.approve, "clearingResult is wrong");
        require(map_clearingInfo[who].isGet == false, "No repeat collection");
        uint256 value = (map_clearingInfo[who].sharesAmount).mul(IERC20(assetAddress).balanceOf(address(this))).div(totalShares);
        bool r = IERC20(assetAddress).transfer(who,value);
        require(r,"error");
        map_clearingInfo[who].isGet = true;
        totalShares = totalShares.sub(map_clearingInfo[who].sharesAmount);
    }

    function() external payable{
    }
}