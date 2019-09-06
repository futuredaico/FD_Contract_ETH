pragma solidity >=0.4.22 <0.6.0;

import "../lib/SafeMath.sol";
import "../Own/Own.sol";
import "../Interface/IERC20.sol";

contract ClearingFundPool is Own{
    using SafeMath for uint256;

    mapping(address=>clearingInfo) public map_clearingInfo;

    enumVoteResult public clearingResult = enumVoteResult.waiver;

    uint256 public totalFdt;

    address public address_erc20;

    struct clearingInfo{
        uint256 fdtAmount;
        bool isGet;
    }

    /// @notice 投票的结果
    enum enumVoteResult {
        waiver,
        approve,
        refuse
    }

    constructor(address payable _address_governShareManager,address _address_erc20) public{
        owner = _address_governShareManager;
        address_erc20 = _address_erc20;
    }

    function lock(address who,uint256 amount) public isOwner(msg.sender) returns(bool){
        require(clearingResult == enumVoteResult.waiver, "clearingResult is wrong");
        bool r = IERC20(address_erc20).transferFrom(owner,address(this),amount);
        require(r==true, "error");
        map_clearingInfo[who].fdtAmount = map_clearingInfo[who].fdtAmount.add(amount);
        totalFdt = totalFdt.add(amount);
        return true;
    }

    function free(address who) public{
        require(clearingResult == enumVoteResult.refuse, "clearingResult is wrong");
        require(map_clearingInfo[who].isGet == false, "No repeat collection");
        bool r = IERC20(address_erc20).transfer(who,map_clearingInfo[who].fdtAmount);
        require(r == true,"error");
        map_clearingInfo[who].isGet = true;
        totalFdt = totalFdt.sub(map_clearingInfo[who].fdtAmount);
    }

    function clear(address payable who) public{
        require(clearingResult == enumVoteResult.approve, "clearingResult is wrong");
        require(map_clearingInfo[who].isGet == false, "No repeat collection");
        uint256 value = (map_clearingInfo[who].fdtAmount).mul(address(this).balance).div(totalFdt);
        who.transfer(value);
        map_clearingInfo[who].isGet = true;
        totalFdt = totalFdt.sub(map_clearingInfo[who].fdtAmount);
    }

    
    function() external payable{
    }
}