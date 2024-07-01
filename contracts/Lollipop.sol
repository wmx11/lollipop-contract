// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract Lollipop is
    ERC20,
    ERC20Burnable,
    ERC20Pausable,
    Ownable,
    ReentrancyGuard
{
    uint256 public constant TOKEN_SUPPLY = 1000000000;
    uint256 public constant MAX_FEE = 10;
    string public constant TOKEN_NAME = "LoIterationEight";
    string public constant TOKEN_SYMBOL = "LIE";

    uint256 public buyFee = 3;
    uint256 public sellFee = 5;

    address public feesReceiver;
    address public feeToken; // WBNB
    address public pair;

    IUniswapV2Router02 public router; // PCS Router

    bool private _isInitialized = false;
    bool private _inSwap = false;

    mapping(address => bool) public isFeeExempt;

    event SetInitialized();
    event SetSellFee(uint256 fee);
    event SetBuyFee(uint256 fee);
    event SetFeeToken(address _address);
    event SetPair(address _address);
    event SetRouter(address _address);
    event SetFeesReceiver(address _address);
    event SetFeeExemptAddress(address _address, bool _flag);
    event DistributeFees(uint256 _amount);
    event Withdraw(uint256 _balance);
    event WithdrawTokensToFeesReceiver(uint256 _balance);
    event Error(string reason);

    enum TransactionType {
        BUY,
        SELL,
        TRANSFER
    }

    modifier swapping() {
        require(_inSwap == false, "Reentrant swap call!");
        _inSwap = true;
        _;
        _inSwap = false;
    }

    modifier validAddress(address _address) {
        require(_address != address(0x0), "Invalid address");
        _;
    }

    constructor(
        address initialOwner,
        address _router,
        address _feesReceiver
    ) payable ERC20(TOKEN_NAME, TOKEN_SYMBOL) Ownable(initialOwner) {
        _mint(msg.sender, TOKEN_SUPPLY * 10 ** decimals());
        feesReceiver = _feesReceiver;
        router = IUniswapV2Router02(_router);
        feeToken = router.WETH();
        pair = IUniswapV2Factory(router.factory()).createPair(
            address(this),
            router.WETH()
        );

        isFeeExempt[feesReceiver] = true;
        isFeeExempt[initialOwner] = true;
        isFeeExempt[address(this)] = true;
        isFeeExempt[msg.sender] = true;

        super._approve(address(this), address(router), type(uint256).max);
    }

    receive() external payable {}

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    /** One-time only. Called when the contract is deployed. Sets initialized flag to true. */
    function initialize() public onlyOwner {
        _isInitialized = true;
        emit SetInitialized();
    }

    // The following functions are overrides required by Solidity.
    /** Transfer function override. */
    function _update(
        address _sender,
        address _recipient,
        uint256 _amount
    ) internal virtual override(ERC20, ERC20Pausable) {
        uint256 _amountToRecipient;

        if (_isInitialized && _shouldTakeFee(_sender, _recipient)) {
            _amountToRecipient = _takeFee(_sender, _recipient, _amount);
        } else {
            _amountToRecipient = _amount;
        }

        if (_shouldDistributeFee()) {
            _distributeFee();
        }

        super._update(_sender, _recipient, _amountToRecipient);
    }

    /** Checks whether the transfer should deduct fees or not based on the sender and recipient addresses. */
    function _shouldTakeFee(
        address _sender,
        address _recipient
    ) private view returns (bool) {
        if (isFeeExempt[_sender] || isFeeExempt[_recipient]) {
            return false;
        }

        return true;
    }

    /** Checks whether the transfer is able to initiate fee distribution. */
    function _shouldDistributeFee() private view returns (bool) {
        return
            _isInitialized &&
            !_inSwap &&
            msg.sender != pair &&
            (buyFee + sellFee > 0);
    }

    /** A function that initializes fee swap to BNB and transfer to the treasury wallet. */
    function _distributeFee() private nonReentrant swapping {
        uint256 _amount = balanceOf(address(this));
        if (_isInitialized && _amount > 0) {
            _swapFeesForBNB(_amount);
        }
    }

    /** Swaps all the tokens inside the contract into BNB and transfers the resulting BNB to a treasury/fees wallet. */
    function _swapFeesForBNB(uint256 _amount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();

        if (super.allowance(address(this), address(router)) < _amount) {
            super._approve(address(this), address(router), type(uint256).max);
        }

        try
            router.swapExactTokensForETHSupportingFeeOnTransferTokens(
                _amount,
                0,
                path,
                feesReceiver,
                block.timestamp
            )
        {} catch Error(string memory reason) {
            super._update(address(this), feesReceiver, _amount);
            emit Error(reason);
        }

        emit DistributeFees(_amount);
    }

    /** Returns an amount after fees. If fees are greater than 0 ( > 0), the fees will be transferred to this contract address and the amount will be deducted from the final amount. */
    function _takeFee(
        address _sender,
        address _recipient,
        uint256 _amount
    ) internal returns (uint256) {
        uint256 _fee;

        TransactionType _transactionType = _getTransactionType(
            _sender,
            _recipient
        );

        if (_transactionType == TransactionType.BUY) {
            _fee = buyFee;
        } else if (_transactionType == TransactionType.SELL) {
            _fee = sellFee;
        } else {
            _fee = 0;
        }

        uint256 _feeAmount = (_amount * _fee) / 100;

        if (_fee > 0) {
            super._update(_sender, address(this), _feeAmount);
        }

        return _amount - _feeAmount;
    }

    /** Returns an ENUM based on the transaction type. Used to determine whether the transaction is a buy, sell, or a regular transfer  */
    function _getTransactionType(
        address _sender,
        address _recipient
    ) private view returns (TransactionType) {
        if (_sender == pair) {
            return TransactionType.BUY;
        }

        if (_recipient == pair) {
            return TransactionType.SELL;
        }

        return TransactionType.TRANSFER;
    }

    /** OWNER METHODS */
    
    function setSellFee(uint256 fee) external onlyOwner {
        require(fee <= MAX_FEE, "Sell fee cannot be larger than MAX_FEE");
        sellFee = fee;
        emit SetSellFee(fee);
    }

    function setBuyFee(uint256 fee) external onlyOwner {
        require(fee <= MAX_FEE, "Buy fee cannot be larger than MAX_FEE");
        buyFee = fee;
        emit SetBuyFee(fee);
    }

    function setFeeToken(
        address _address
    ) external onlyOwner validAddress(_address) {
        feeToken = _address;
        emit SetFeeToken(_address);
    }

    function setPair(
        address _address
    ) external onlyOwner validAddress(_address) {
        pair = _address;
        emit SetPair(_address);
    }

    function setRouter(
        address _address
    ) external onlyOwner validAddress(_address) {
        router = IUniswapV2Router02(_address);
        emit SetRouter(_address);
    }

    function setFeesReceiver(
        address _address
    ) external onlyOwner validAddress(_address) {
        feesReceiver = _address;
        emit SetFeesReceiver(_address);
    }

    function setFeeExemptAddress(
        address _address,
        bool _flag
    ) external onlyOwner validAddress(_address) {
        isFeeExempt[_address] = _flag;
        emit SetFeeExemptAddress(_address, _flag);
    }

    /** Manual fee distribution call */
    function distributeFee() public onlyOwner {
        _distributeFee();
    }

    /** Withdraw all BNB to the deployer/owner wallet. */
    function withdraw() public onlyOwner {
        uint256 _balance = address(this).balance;
        if (_balance == 0) {
            revert("Insufficient funds");
        }
        payable(msg.sender).transfer(_balance);
        emit Withdraw(_balance);
    }

    /** Withdraw all contract tokens (this) to the fees receiver without swapping them to BNB */
    function withdrawTokensToFeesReceiver() public onlyOwner {
        uint256 _balance = balanceOf(address(this));
        if (_balance == 0) {
            revert("Insufficient funds");
        }
        super._update(address(this), feesReceiver, _balance);
        emit WithdrawTokensToFeesReceiver(_balance);
    }
}
