pragma solidity >=0.4.22 <0.6.0;

import "./FundPool.sol";

contract Jump{
    constructor() public{

    }

    struct Project{
        uint256 index;
        address creater;
        string projectName;
        address fundPoolContract;
        address voteContract;
    }

    Project[] projectQueue;

    /* events */
    event OnCreate(uint256 index ,address creater,string  projectName,address fundPoolAddress,address voteAddress);

    function createProject(string memory _name,uint256 _days,uint256 _money,uint256 _slope,uint256 _alpha,uint256 _beta) public{
        FundPool fundpool = new FundPool(_name,_days,_money,_slope,_alpha,_beta);
        address voteAddress = fundpool.getVoteContract();
        Project memory project = Project({
            index:projectQueue.length,
            creater : msg.sender,
            projectName : _name,
            fundPoolContract : address(fundpool),
            voteContract:voteAddress
        });
        projectQueue.push(project);
        emit OnCreate(project.index,project.creater,project.projectName,address(fundpool),voteAddress);
    }
}