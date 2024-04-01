// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {IWETH} from "../src/UniSwapV2/interface/IWETH.sol";
import {UniV2FlashSwap} from "../src/UniSwapV2/UniV2FlashSwap.sol";

address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

contract UniV2FlashSwapTest is Test {
    IWETH private weth = IWETH(WETH);
    UniV2FlashSwap private uni;

    function setUp() public {
        uni = new UniV2FlashSwap();
    }

    function test_UniV2flashSwap() public {
        weth.deposit{value: 1e18}();
        //approve flash swap fee
        weth.approve(address(uni), 1e18);

        uint256 amountToBorrow = 10 * 1e18;
        uni.flashSwap(amountToBorrow);

        assertGt(uni.amountToRepay(), amountToBorrow);
    }
}
