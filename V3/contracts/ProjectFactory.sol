pragma solidity >=0.4.22 <0.6.0;
import "./FundPool.sol";

/// @title 工厂合约
/// @author viko
/// @notice 调用createProject创建fundpool合约以及vote合约
contract ProjectFactory{
    /// @notice 项目的结构
    struct Project{
        uint256 index;
        address creater;
        string projectName;
        address fundPoolContract;
        address voteContract;
    }

    /// @notice 用来存储所有的项目
    Project[] projectQueue;

    /* events */
    event OnCreate(
        uint256 index,
        address creater,
        string  projectName,
        address fundPoolAddress,
        address voteAddress
    );

    /// @notice 创建一个工程
    /// @dev 创建工程等于创建了两个合约，一个是vote合约，一个是fundpool合约。两个合约的hash用event的方式抛出。
    /// @param _name 需要传入项目的名称，_days 项目需要众筹的总耗时，_money 项目众筹的资金
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