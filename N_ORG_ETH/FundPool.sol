pragma solidity >=0.4.22 <0.6.0;
import "./Vote.sol";
contract N_FundPool{
    uint public slope = 10**12;  //分母
    uint public alpha = 700; //投资者购买时所使用的分子，意味着7成进入储备，3成进入自治；
    uint public beta = 800; //项目盈利时购买使用的分子
    uint public crowdFundDays = 30; //众筹的天数 单位是天
    uint public crowdFundMoney = 10000; //众筹的目标
    uint public crowdFundStartTime;//众筹开始时间
    bool public crowdFunding = true; //是否处于众筹期间
    string public name; //项目名称
    mapping (address=>uint) public crowdFundingEth; //众筹期间募集的eth

    uint public totalSupply = 0; //fnd发行的总量
    mapping(address=>uint)  public balances;//记录每个地址拥有的fnd数量
    address public owner; //合约的拥有着
    uint public sellReserve = 0;//当前储备池中的存款

    uint totalSendToVote = 0; //发送给项目方的钱总数

    N_Vote vote;
    /* events */
    event OnBuy(address who,uint256 ethAmount,uint256 nfdAmount); //购买
    event OnSell(address who,uint256 ethAmount,uint256 nfdAmount); //出售
    event OnRevenue(address who,uint256 ethAmount,uint256 nfdAmount);//利润回购
    event OnWindingUp(address who,uint256 ethAmount); //清退

    //初始函数
    constructor(string memory _name,uint d,uint m,uint s,uint a ,uint b) public{
        owner = msg.sender;
        require(bytes(_name).length>0);
        require(d>0);
        require(m>0);
        require(s>0);
        require(a>0);
        require(b>0);
        name = _name;
        crowdFundDays = d;
        crowdFundMoney =m;
        crowdFundStartTime = now;
        slope = s;
        alpha = a;
        beta = b;
        vote = new N_Vote(owner,this);
    }

    modifier isOwner() {
        require(owner == msg.sender, "limited authority");
        _;
    }

    //获取vote合约
    function getVoteContract() public view returns(address){
        return address(vote);
    }

    //管理员重新设置参数
    function setSlope(uint _slope) public  isOwner() {
        slope = _slope;
    }
    function setAlpha(uint _alpha) public isOwner() {
        alpha = _alpha;
    }
    function setBeta(uint _beta) public isOwner() {
        beta = _beta;
    }

    //开根号的计算方法
    function sqrt(uint x) pure private returns(uint) {
        uint z = (x+1)/2;
        uint y = x;
        while(z<y)
        {
            y =z;
            z =(x/z +z)/2;
        }               
        return y;
    }

    //众筹失败，清退
    function windingUp() public {
        require(now - crowdFundStartTime > 30 days,"need beyond the corwdfunding period");        
        require(crowdFunding == true,"need corwdfunding");
        require(crowdFundingEth[msg.sender]>0,"need has eth");
        uint256 value = crowdFundingEth[msg.sender];
        msg.sender.transfer(value);
        crowdFundingEth[msg.sender] = 0;
        emit OnWindingUp(msg.sender,value);
    }

    //投资者购买
    function buy() public payable {
        require(msg.value > 0);
        uint invest = msg.value;
        uint fndAmount =  sqrt(2* invest *1000/slope + totalSupply*totalSupply) - totalSupply;
        balances[msg.sender] += fndAmount;
        totalSupply += fndAmount;

        uint256 sendToVote = 0;

        //如果储备池里的钱少于7成，就优先放储备池里
        uint256 sendtoSellReserve = alpha * (totalSendToVote + sellReserve) / 1000 - sellReserve <=0 ? 0: (alpha/1000) * (totalSendToVote + sellReserve) - sellReserve ;
        
        if(sendtoSellReserve<=0)//如果储备池钱多就正常73分
        {
            //存在本合约储备池里的钱
            sellReserve += alpha * invest;
            //发给项目池用作发展的钱
            sendToVote= (1000-alpha)* invest;
        }
        else if(sendtoSellReserve/1000 >= invest)//如果储备池钱少并且少的这次补不上，就全部放进储备池
        {
            sellReserve += invest * 1000;
            sendToVote = 0;
        }
        else //储备池钱少，先补满，然后再73分
        {
            sellReserve += sendtoSellReserve;

            sellReserve += (invest-sendtoSellReserve/1000) * alpha;
            sendToVote  = (invest-sendtoSellReserve/1000) * (1000-alpha);
        }

        totalSendToVote += sendToVote;
        sendToVote /= 1000;

        if(crowdFunding == false) //如果不在众筹期了，转部分钱给vote
            address(vote).transfer(sendToVote);
        else if(totalSendToVote+sellReserve>=crowdFundMoney * 1000)
        {
            require(now - crowdFundStartTime <= 30 days,"Beyond the crowdfunding period");
            crowdFunding = false;
            address(vote).transfer(totalSendToVote/1000);
        }
        else
        {
            crowdFundingEth[msg.sender] += msg.value;
            require(now - crowdFundStartTime <= 30 days,"Beyond the crowdfunding period");
        }

        emit OnBuy(msg.sender,msg.value,fndAmount);
    }

    //投资者出售
    function sell(uint amount) public{
        require(crowdFunding== false,"need Beyond the crowdfunding period");
        require(amount > 0);
        require (balances[msg.sender] >= amount);
        uint withdraw = sellReserve*amount*(2*totalSupply - amount)/totalSupply/totalSupply;
        balances[msg.sender] -= amount;
        totalSupply -= amount;
        sellReserve -= withdraw;
        require(sellReserve>=0);
        withdraw /= 1000;
        msg.sender.transfer(withdraw);
        emit OnSell(msg.sender,withdraw,amount);
    }

    //收入  和投资相比，不给某人的账户增加对应的fnd
    function revenue() public payable{
        require(msg.value > 0);
        uint invest = msg.value;
        uint fndAmount =  sqrt(2* invest *1000/slope + totalSupply*totalSupply) - totalSupply;
        totalSupply += fndAmount;
        //存在本合约储备池里的钱
        sellReserve += beta * invest;
        //发给项目池用作发展的钱
        uint256 sendToVote =(1000-beta)* invest;
        totalSendToVote += sendToVote;
        address(vote).transfer(sendToVote/1000);
        emit OnRevenue(msg.sender,msg.value,fndAmount);
    }
}