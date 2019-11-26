pragma solidity >=0.4.22 <0.6.0;

import "../Interface/IERC20.sol";
import "../lib/SafeMath.sol";
import "../lib/Context.sol";
import "../apps/FutureDaoApp.sol";

contract sharesB is IERC20 , Context , FutureDaoApp{
    using SafeMath for uint256;

    string public name;
    uint8 public decimals;
    string public symbol;

    uint256 private _totalSupply;
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;

    //////////////
    ///auth
    //////////////
    bytes32 public constant SharesB_Mint = keccak256("SharesB_Mint");
    bytes32 public constant SharesB_Burn = keccak256("SharesB_Burn");

    constructor(AppManager _appManager,string memory _name,uint8 _decimals,string memory _symbol) FutureDaoApp(_appManager) public {
        name = _name;
        decimals = _decimals;
        symbol = _symbol;
    }

    ///////////////
    //ERC20 Methods
    ///////////////

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function mint(address account,uint256 amount) public auth(SharesB_Mint) returns (bool){
        _mint(account,amount);
        return true;
    }

    function burn(uint256 amount) public returns (bool){
        _burn(msg.sender,amount);
        return true;
    }

    function burn(address account,uint256 amount) public auth(SharesB_Burn) returns (bool){
        _burn(account,amount);
        return true;
    }

    function burnSelfToken(uint256 amount) public returns(bool){
        _burn(msg.sender,amount);
        return true;
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 value) internal {
        require(account != address(0), "ERC20: burn from the zero address");

        _balances[account] = _balances[account].sub(value);
        _totalSupply = _totalSupply.sub(value);
        emit Transfer(account, address(0), value);
    }
}