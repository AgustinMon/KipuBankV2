// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.0;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Oracle} from "./Oracle.sol";

/// @title KipuBank - Un banco simple para depósitos y retiros de ETH
/// @author Agustín M.
/// @notice This contract allows users to deposit and withdraw ether with certain limits.
/// @notice Minimum deposit amount: 0.01 ether.
/// @notice Límite máximo de retiro por transacción: definido en el deploy.
/// @dev Incluye funciones especiales del owner que permiten al dueño devolver fondos a usuarios.
contract KipuBankV2 is AccessControl{

    ///CONFIG
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant ACCOUNTANT_ROLE = keccak256("ACCOUNTANT_ROLE");
    address immutable public owner; /// public para generar transparencia
    uint256 immutable MAXIMUMTOWITHDRAW; /// cantidad maxima para retirar en una sola transaccion
    uint256 immutable BANKCAP; /// cantidad maxima global de depositos en el contrato
    uint256 public constant MINIMUMDEPOSITAMOUNT = 0.01 ether; /// cantidad minima para depositar

    /// COINS

    IERC20 immutable public USDC;

    mapping(address => mapping(address => uint256)) public balance;

    Oracle immutable public datafeed;

    uint256 public totalDeposits; /// variable para llevar el control de los depositos globales
    uint256 public totalWithdraws; /// variable para llevar el control de los retiros globales
    
    error InvalidMinimum();///Invalid minimum deposit
    error InvalidContract(); /// Invalid contract address
    error NotTheOwner(); /// Not the owner of the contract
    error InvalidAmountToWithdraw(); ///Invalid amount to withdraw
    error ExceededGlobalLimit(); ///Exceded global deposit limit
    error TransferFailed(); /// Transfer failed
    error InvalidPriceFromOracle(); /// Invalid price from oracle

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
        uint256 ethBalance = address(this).balance +  msg.value;
        if (ethBalance > BANKCAP) revert ExceededGlobalLimit();
        _;
    }

    /// @dev deposit limits are set at deployment
    constructor(uint256 _globalDepositLimit, IERC20 _usdcAddress, Oracle _datafeed) {
        owner = msg.sender; 
        _grantRole(ADMIN_ROLE, owner);
        _grantRole(ACCOUNTANT_ROLE, owner);//could be any other, I put the owner for simplicity
        if(address(_usdcAddress) == address(0)) revert InvalidContract();
        USDC = _usdcAddress;
        MAXIMUMTOWITHDRAW = 0.01 ether; 
        BANKCAP = _globalDepositLimit; 
        datafeed = _datafeed;
    }


    /**
     * @notice Add ether to your balance, only if the amount is greater 0.1 ether 
     */
    function addEth() external payable VerifyMinimumDeposit VerifyMaxBankCapLimit{
        address sender = msg.sender;
        uint256 amount = uint256(msg.value);
        //if ((balance[sender][address(0)] += amount) > BANKCAP) revert ExceededGlobalLimit();
        balance[sender][address(0)] += amount;
        ++totalDeposits;
        emit Deposited(sender, amount); 
    }

    /**
     * @notice Add ether to your balance and transform it into usdc, only if the amount is greater 0.1 ether 
     */
    function addUSDC() external payable VerifyMinimumDeposit VerifyMaxBankCapLimit{
        address sender = msg.sender;
        uint256 ethAmount = uint256(msg.value);
        uint256 amountInUSDC = _convertEthToToken(ethAmount);
        //if ((balance[sender][address(0)] + ethAmount) > BANKCAP) revert ExceededGlobalLimit();
        balance[sender][address(USDC)] += amountInUSDC;
        ++totalDeposits;
        emit Deposited(sender, ethAmount);
    }

    /**
     * @notice Returns the ETH and USDC balance of any address
     */
    function getBalance(address _anyAddress) external view returns(uint256 ethBalance, uint256 usdcBalance) {
        ethBalance = balance[_anyAddress][address(0)];
        usdcBalance = balance[_anyAddress][address(USDC)];
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
    * @notice Only admin role can call this function for security reasons.
    * @return uint256 = total withdraws made by users
    */
    function getTotalWithdraws() external onlyRole(ACCOUNTANT_ROLE) view returns(uint256) {
        return totalWithdraws;
    }

    /**  
    * @notice Function to get the total value of the contract and add public transparency.
    * @notice Only admin role can call this function for security reasons.
    * @return uint256 = total balance of the whole contract
    */
    function getTotalAllocated() external onlyRole(ACCOUNTANT_ROLE) view returns(uint256) {
        return address(this).balance; 
    }

     /**
     * @dev JUST FOR ADMIN FUNCTION
     * @dev Important problem if usdc depegs, not enough eth to retrieve. I just send total eths available!
     * @notice Function for the owner to withdraw and send all it balance to a third party address
     * @param _anyAddrress = direccion del contrato de terceros
     */
    function withdrawAll(address _anyAddrress) external onlyRole(ADMIN_ROLE) returns(bytes memory) {
        ///checks
        address to = _anyAddrress;
        uint256 userBalance = balance[to][address(0)];
        uint256 userBalanceUsdc = _convertTokenToWei(balance[to][address(USDC)]);
        uint256 totalUserBalance = userBalance + userBalanceUsdc; //totalUserBalance may be more than actual eth balance
        /// effects
        /// just zeroing the balance
        balance[to][address(USDC)] = 0;
        balance[to][address(0)] = _substractBalance(totalUserBalance, totalUserBalance);
        /// prevenido contra reentrancy attack
        ++totalWithdraws;

        /// interaction
        /// just returning all the eth available in the contract, not usdc!
        (bool success, bytes memory data) = to.call{value: userBalance}("");
        if(!success) revert TransferFailed(); //send converted tokens to USDC contract

        emit WithDrawn(msg.sender, userBalance); /// evento para web3
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
        if (_actualBalance == 0) revert InvalidAmountToWithdraw();
        if (_amountToReduce > _actualBalance) revert InvalidAmountToWithdraw();
        if (_amountToReduce > MAXIMUMTOWITHDRAW && msg.sender != owner) revert InvalidAmountToWithdraw();
        unchecked {
            return _actualBalance - _amountToReduce;
        }
    }

    /**
     * @notice converts eth (expressed in weis) to usdc (expressed in 18 decimals)
     * @param _ethAmount = eth quantity
     * @return uint256 = equivalent usdc tokens in 18 decimals
     * @dev eth price obtained from Chainlink Oracle
     */

    function _convertEthToToken(uint256 _ethAmount) internal view returns (uint256) {
        int ethUsd = datafeed.getLatestPrice();
        if (ethUsd <= 0) revert InvalidPriceFromOracle();

        uint256 tokenAmount;
        uint8 oracleDecimals = 8;

        unchecked {
            // Si el token vale 1 USD y tiene 18 decimales:
            // tokenAmount = (ETH en wei * precio ETH/USD) / 10^oracleDecimals
            tokenAmount = (_ethAmount * uint256(ethUsd)) / (10 ** oracleDecimals);
        }

        return tokenAmount; // Devuelve el equivalente en tokens (18 decimales)
    }

    /**
     * @notice converts usdc tokens (expressed in 18 decimals) to Eth, expressed in wei
     * @param _ethAmount = usdc tokens quantity
     * @return uint256 = equivalen eth expressed in wei
     * @dev eth price obtained from Chainlink Oracle
     */
    function _convertTokenToWei(uint256 _tokenAmount) internal view returns (uint256) {
    int ethUsd = datafeed.getLatestPrice();
    if (ethUsd <= 0) revert InvalidPriceFromOracle();

    uint8 oracleDecimals = 8;
    uint256 ethAmount;

    unchecked {
        // ETH = (tokenAmount * 10^oracleDecimals) / (precio ETH/USD)
        ethAmount = (_tokenAmount * (10 ** oracleDecimals)) / uint256(ethUsd);
    }
        return ethAmount; 
    }
}