// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IWETH} from "./interfaces/IWETH.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {ISwapRouter02} from "./interfaces/ISwapRouter02.sol";

address constant SWAP_ROUTER_02 = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

contract UniSwapV3MultiHopSwap {
    ISwapRouter02 private constant ROUTER = ISwapRouter02(SWAP_ROUTER_02);
    IERC20 private constant _WETH = IERC20(WETH);
    IERC20 private constant _DAI = IERC20(DAI);

    function swapExactInputMultiHop(
        uint256 amountIn,
        uint256 amountOutMin
    ) external {
        _WETH.transferFrom(msg.sender, address(this), amountIn);
        _WETH.approve(address(ROUTER), amountIn);

        bytes memory path = abi.encodePacked(
            WETH,
            uint24(3000),
            USDC,
            uint24(100),
            DAI
        );

        ISwapRouter02.ExactInputParams memory params = ISwapRouter02
            .ExactInputParams({
                path: path,
                recipient: msg.sender,
                amountIn: amountIn,
                amountOutMinimum: amountOutMin
            });

        ROUTER.exactInput(params);
    }

    function swapExactOutputMultiHop(
        uint256 amountOut,
        uint256 amountInMax
    ) external {
        _WETH.transferFrom(msg.sender, address(this), amountInMax);
        _WETH.approve(address(ROUTER), amountInMax);

        bytes memory path = abi.encodePacked(
            DAI,
            uint24(100),
            USDC,
            uint24(3000),
            WETH
        );
        ISwapRouter02.ExactOutputParams memory params = ISwapRouter02
            .ExactOutputParams({
                path: path,
                recipient: msg.sender,
                amountOut: amountOut,
                amountInMaximum: amountInMax
            });

        uint256 amountIn = ROUTER.exactOutput(params);

        if (amountIn < amountInMax) {
            _WETH.approve(address(ROUTER), 0);
            _WETH.transfer(msg.sender, amountInMax - amountIn);
        }
    }
}
