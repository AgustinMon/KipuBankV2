// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity >=0.8.0; 

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Oracle} from "./oracle.sol";

/// @title KipuBank - Un banco simple para depósitos y retiros de ETH
/// @author Agustín M.
/// @notice This contract allows users to deposit and withdraw ether with certain limits.
/// @notice Minimum deposit amount: 0.01 ether.
/// @notice Límite máximo de retiro por transacción: definido en el deploy.
/// @dev Incluye funciones especiales del owner que permiten al dueño devolver fondos a usuarios.
contract KipuBankV2 {

    ///CONFIG
    address immutable public owner; /// public para generar transparencia
    uint256 immutable MAXIMUMTOWITHDRAW; /// cantidad maxima para retirar en una sola transaccion
    uint256 immutable BANKCAP; /// cantidad maxima global de depositos en el contrato
    uint256 public constant MINIMUMDEPOSITAMOUNT = 0.01 ether; /// cantidad minima para depositar

    /// COINS
    struct Balances{
        uint256 eth;
        uint256 usdc;
        uint256 total;
    }
    IERC20 immutable public USDC;


    mapping (address => Balances) public balance;
    Oracle immutable public datafeed;


    uint256 public totalDeposits; /// variable para llevar el control de los depositos globales
    uint256 public totalWithdraws; /// variable para llevar el control de los retiros globales
    
    error InvalidMinimum();///Invalid minimum deposit
    error InvalidContract(); /// Invalid contract address
    error NotTheOwner(); /// Not the owner of the contract
    error InvalidAmountToWothdraw(); ///Invalid amount to withdraw
    error ExceededGlobalLimit(); ///Exceded global deposit limit
    error TransferFailed(); /// Transfer failed

    event Deposited(address indexed  payer, uint256 amount); /// event emited on deposit
    event WithDrawn(address indexed withdrawer, uint256 amount); /// event emited on withdraw

    /**
     * @dev Modifier to restrict functions to only the contract owner
     */
    modifier onlyOwner() { 
        if(msg.sender != owner) revert NotTheOwner();
        _;
    }

    /**
     * @dev Modifier to verify that the deposit amount meets the minimum requirement
     */
    modifier VerifyMinimumDeposit() {
        if(msg.value < MINIMUMDEPOSITAMOUNT) revert InvalidMinimum();
        _;
    }

    modifier VerifyMaxBankCapLimit() {
        // balance actual en ETH del contrato + lo que entra en esta tx
        uint256 ethBalance = address(this).balance + msg.value;

        // balance del token del contrato
        uint256 tokenBalance = USDC.balanceOf(address(this));

        // convertir tokenBalance a ETH
        uint256 tokenInEth = _convertTokenToEth(tokenBalance);

        uint256 totalBalanceEth = ethBalance + tokenInEth;

        if (totalBalanceEth > BANKCAP) revert ExceededGlobalLimit();
        _;
    }

    /// @dev deposit limits are set at deployment
    constructor(uint256 _globalDepositLimit, IERC20 _usdcAddress, Oracle _datafeed) {
        if(address(_usdcAddress) == address(0)) revert InvalidContract();
        owner = msg.sender; 
        USDC = _usdcAddress;
        MAXIMUMTOWITHDRAW = 0.01 ether; 
        BANKCAP = _globalDepositLimit; 

        datafeed = _datafeed;
    }



    function _convertTokenToEth(uint256 tokenAmount) internal view returns (uint256) {
        (, int ethUsd, , ,) = ethFeed.latestRoundData();
        (, int tokenUsd, , ,) = tokenFeed.latestRoundData();

        require(ethUsd > 0 && tokenUsd > 0, "Invalid oracle price");

        // convertir todo a uint256 para cálculos seguros
        uint256 ethUsdU = uint256(ethUsd);
        uint256 tokenUsdU = uint256(tokenUsd);

        // si los feeds tienen 8 decimales, ajustamos a 18 decimales (wei)
        // esto depende del feed exacto que uses
        uint8 decimals = 8;

        // tokenInEth = tokenAmount * tokenUSD / ethUSD
        uint256 tokenInEth = (tokenAmount * tokenUsdU) / ethUsdU;

        // ajustar por decimales del feed
        return tokenInEth / (10 ** decimals);
    }


    /**
     * @notice Add ether to your balance, only if the amount is greater 0.1 ether 
     */
    function addEth() external payable VerifyMinimumDeposit VerifyMaxBanckapLimit{
        address sender = msg.sender;
        uint256 amount = uint256(msg.value);
        if ((balance[sender].eth += amount) > BANKCAP) revert ExceededGlobalLimit();
        ++totalDeposits;
        emit Deposited(sender, amount); 
    }

    /**
     * @notice Add ether to your balance and transform it into usdc, only if the amount is greater 0.1 ether 
     */
    function addUSDC() external payable VerifyMinimumDeposit VerifyMaxBanckapLimit{
        address sender = msg.sender;
        uint256 amount = uint256(msg.value);
        uint256 amountInUSDC = (amount * 1e8)/uint256(datafeed.getLatestPrice());
        if ((balance[sender].usdc += amountInUSDC) > BANKCAP) revert ExceededGlobalLimit();
        ++totalDeposits;
        emit Deposited(sender, amount);
    }

    /** 
    *  @notice Function for the msg.sender to withdraw a partial amount
    */
    function withdrawPartialUsers(uint256 _amount) external returns (bytes memory) {
        /// checks
        uint256 amount = _amount;
        uint256 userBalance = balance[msg.sender].eth;
        
        /// effects
        /// chequeo balance > amount en _substractBalance
        balance[msg.sender].eth = _substractBalance(userBalance, amount);
        /// prevenido contra reentrancy attack
        ++totalWithdraws;

        /// interaction
        (bool success, bytes memory data) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();

        emit WithDrawn(msg.sender, amount); /// evento para web3
        return data;
    }

     /**
     * @notice returns the balance of the account that is using the contract.
     * @return uint256 = Account balance
     */
    function getBalance() external view returns(uint256) {
        return balance[msg.sender].eth;
    }

     /**
     * @notice returns total number of deposits made by users. Does not consider deposits made by the owner
     * @return uint256 = total deposits made by users
     */
    function getTotalDeposits() external view returns(uint256) {
        return totalDeposits;
    }

    /**
    * @notice Returns total number of withdraws made by users. Does not consider withdrawals made by the owner
    * @return uint256 = total withdraws made by users
    */
    function getTotalWithdraws() external view returns(uint256) {
        return totalWithdraws;
    }

    /**  
    * @notice Function to get the total value of the contract and add public transparency.
    * @return uint256 = total balance of the whole contract
    */
    function getTotalAllocated() external view returns(uint256) {
        return address(this).balance; 
    }

    /**
     * @dev JUST FOR CONTRACT OWNER FUNCTION
     * Function for the owner to withdraw and send all it balance to a third party address
     * @param _anyAddrress = direccion del contrato de terceros
     */
    function withdrawAll(address _anyAddrress) external onlyOwner returns(bytes memory) {
        ///checks
        address to = _anyAddrress;
        uint256 userBalance = balance[_anyAddrress].eth;

        /// effects
        balance[_anyAddrress].eth = _substractBalance(userBalance, userBalance);
        /// prevenido contra reentrancy attack
        ++totalWithdraws;

        /// interaction
        (bool success, bytes memory data) = to.call{value: userBalance}("");
        if(!success) revert TransferFailed();

        emit WithDrawn(msg.sender, userBalance); /// evento para web3
        return data;
    }

    /**
    * @dev JUST FOR CONTRACT OWNER FUNCTION
    * @notice Function for the owner to withdraw a partial it amount to a third party address
    * @param _anyAddress = third party address
    * @param _amount = amount to be withdrawn
    */
    function withdrawPartialFromOwner(address _anyAddress, uint256 _amount) external onlyOwner returns (bytes memory) {
        ///checks
        uint256 userBalance = balance[_anyAddress].eth;

        /// effects
        /// chequeo balance > amount en _substractBalance
        balance[_anyAddress].eth = _substractBalance(userBalance, _amount);
        /// prevenido contra reentrancy attack
        ++totalWithdraws;

        /// interactions
        (bool success, bytes memory data) = payable(_anyAddress).call{value: _amount}("");
        if (!success) revert TransferFailed();

        emit WithDrawn(_anyAddress, _amount); //evento para web3
        return data;
    }

    /**
    * @notice Reduce el balance de una direccion en una cantidad determinada
    * @notice Independientemente de que consume un poquito más gas, se decidió crear esta función para separar trabajos.
    * @notice Reduces the balance of an address by a determined amount
    * @notice Regardless of whether more gas is consumed, it was decided to create this function to separate tasks
    * @param _actualBalance = balance before reduction
    * @param _amountToReduce = amount to be reduced from balance
    * @return uint256 = returns updated balance
    * @dev Solo el owner puede retirar más de MAXIMUMTOWITHDRAW
    */
    function _substractBalance(uint256 _actualBalance, uint256 _amountToReduce) private view returns (uint256) {
        if (_actualBalance == 0) revert InvalidAmountToWothdraw();
        if (_amountToReduce > _actualBalance) revert InvalidAmountToWothdraw();
        if (_amountToReduce > MAXIMUMTOWITHDRAW && msg.sender != owner) revert InvalidAmountToWothdraw();
        unchecked {
            return _actualBalance - _amountToReduce;
        }
    }
}