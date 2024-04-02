// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {UniV2SwapExample} from "../src/UniSwapV2/UniV2Swap.sol";
import {IERC20} from "../src/UniSwapV2/interface/IERC20.sol";
import {IWETH} from "../src/UniSwapV2/interface/IWETH.sol";

address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

contract UniV2SwapTest is Test {
    IWETH private weth = IWETH(WETH);
    IERC20 private dai = IERC20(DAI);
    IERC20 private usdc = IERC20(USDC);

    UniV2SwapExample private uni;

    function setUp() public {
        uni = new UniV2SwapExample();
    }

    // swap WETH -> DAI
    function test_SwapSingleHopExactAmountIn() public {
        uint256 wethAmount = 1e18;
        weth.deposit{value: wethAmount}();
        weth.approve(address(uni), wethAmount);

        uint256 daiAmountMin = 1;
        uint256 daiAmountOut = uni.swapSingleHopExactAmountIn(
            wethAmount,
            daiAmountMin
        );

        console2.log("DAI: ", daiAmountOut);
        assertGe(daiAmountOut, daiAmountMin, "amountOut<Min");
    }

    // swap dai-weth-usdc
    function test_MultiHopExactAmountIn() public {
        // swap weth-dai
        uint256 wethAmount = 1e18;
        weth.deposit{value: wethAmount}();
        weth.approve(address(uni), wethAmount);

        uint256 daiAmountMin = 1;
        uni.swapMultiHopExactAmountIn(wethAmount, daiAmountMin);

        //swap dai-weth-usdc
        uint256 daiAmountIn = 1e18;
        dai.approve(address(uni), daiAmountIn);

        uint256 usdcAmountOutMin = 1;
        uint256 usdcAmountOut = uni.swapMultiHopExactAmountIn(
            daiAmountIn,
            usdcAmountOutMin
        );

        console2.log("USDC: ", usdcAmountOut);
        assertGe(usdcAmountOut, usdcAmountOutMin, "amountOut<min");
    }

    //exactamountOut
    // swap weth-dai
    function test_SingleHopExactAmountOut() public {
        uint256 wethAmount = 1e18;
        weth.deposit{value: wethAmount}();
        weth.approve(address(uni), wethAmount);

        uint256 daiAmountDesired = 1e18;
        uint256 daiAmountOut = uni.swapSingleHopExactAmountOut(
            daiAmountDesired,
            wethAmount
        );

        console2.log("DAI: ", daiAmountOut);
        assertEq(
            daiAmountOut,
            daiAmountDesired,
            "amountout not equal to amountdesired"
        );
    }

    // swap dai-weth-usdc
    function test_MultiHopExactAmountOut() public {
        // swap weth-dai
        uint256 wethAmount = 1e18;
        weth.deposit{value: wethAmount}();
        weth.approve(address(uni), wethAmount);

        // buy 100 dai
        uint256 daiAmountOut = 100 * 1e18;
        uni.swapSingleHopExactAmountOut(daiAmountOut, wethAmount);

        // Swap dai-weth-usdc
        dai.approve(address(uni), daiAmountOut);

        uint256 amountOutDesired = 1e6;
        uint256 amountOut = uni.swapMultiHopExactAmountOut(
            amountOutDesired,
            daiAmountOut
        );

        console2.log("USDC: ", amountOut);
        assertEq(amountOut, amountOutDesired, "amountOut != amountOutDesired");
    }
}
