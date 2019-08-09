pragma solidity >=0.4.22 <0.6.0;
import "./TradeFundPool.sol";
import "./GovernFundPool.sol";

/// @title 工厂合约
/// @author viko
/// @notice 调用createProject创建fundpool合约以及vote合约
contract ProjectFactory{
    /// @notice 项目的结构
    struct Project{
        uint256 index;
        address creater;
        string projectName;
        address tradeFundPoolAddress;
        address governFundPoolAddress;
    }

    address owner;

    /// @notice 用来存储所有的项目
    Project[] projectQueue;

    /* events */
    event OnCreate(
        uint256 index,
        address creater,
        string  projectName,
        address tradeFundPoolAddress,
        address governFundPoolAddress
    );

    /// @notice 判断是不是合约的所有者
    modifier isOwner() {
        require(owner == msg.sender, "limited authority");
        _;
    }

    constructor() public {
        owner = msg.sender;
    }

    /// @notice 创建一个工程
    /// @dev 创建工程等于创建了两个合约，一个是vote合约，一个是fundpool合约。两个合约的hash用event的方式抛出。
    /// @param _name 需要传入项目的名称，_days 项目需要众筹的总耗时，_money 项目众筹的资金
    function createProject(string memory _name,TradeFundPool _tradeFundpool,GovernFundPool _governFundPool) public isOwner(){
        Project memory project = Project({
            index:projectQueue.length,
            creater : msg.sender,
            projectName : _name,
            tradeFundPoolAddress : address(_tradeFundpool),
            governFundPoolAddress:address(_governFundPool)
        });
        projectQueue.push(project);
        //耦合
        _tradeFundpool.unsafe_setGovernFundPool(_governFundPool);
        _governFundPool.unsafe_setTradeFundPool(_tradeFundpool);
        emit OnCreate(project.index,project.creater,project.projectName,project.tradeFundPoolAddress,project.governFundPoolAddress);
    }

    /// @notice 获取已经创立的项目数
    function getProjectCount() public view returns(uint256 count) {
        count = projectQueue.length;
    }

    /// @notice 获取项目详情
    /// @param _index 项目的序列号
    function getProjectInfoByIndex(uint256 _index)
    public
    view
    returns(
        address creater,
        string memory name,
        address tradeFundPoolAddress,
        address governFundPoolAddress
        )
    {
        require(_index < projectQueue.length, "out of range");
        Project memory project = projectQueue[_index];
        creater = project.creater;
        name = project.projectName;
        tradeFundPoolAddress = project.tradeFundPoolAddress;
        governFundPoolAddress = project.governFundPoolAddress;
    }
}