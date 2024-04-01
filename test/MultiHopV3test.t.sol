// SPDX-License-Identifier:MIT
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {UniSwapV3MultiHopSwap} from "../src/ MultiHopSwapV3.sol";
import {IWETH} from "../src/interfaces/IWETH.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {ISwapRouter02} from "../src/interfaces/ISwapRouter02.sol";

contract UniV3MultiHopTest is Test {
    address private constant SWAP_ROUTER_02 =
        0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address private constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    IWETH private constant _WETH = IWETH(WETH);
    IERC20 private constant _DAI = IERC20(DAI);
    IERC20 private constant _USDC = IERC20(USDC);

    UniSwapV3MultiHopSwap private multiswap;

    uint256 private constant AMOUNT_IN = 10 * 1e18;
    uint256 private constant AMOUNT_OUT = 20 * 1e18;
    uint256 private constant MAX_AMOUNT_IN = 1e18;

    function setUp() public {
        multiswap = new UniSwapV3MultiHopSwap();
        _WETH.deposit{value: AMOUNT_IN + MAX_AMOUNT_IN}();
        _WETH.approve(address(multiswap), type(uint256).max);
    }

    function test_swapExactInputMultiHop() public {
        multiswap.swapExactInputMultiHop(AMOUNT_IN, 1);
        uint256 d1 = _DAI.balanceOf(address(this));
        assertGt(d1, 0, "DAI balnce = 0");
    }

    function test_swapExactOutputMultiHop() public {
        uint256 w0 = _WETH.balanceOf(address(this));
        uint256 d0 = _DAI.balanceOf(address(this));
        multiswap.swapExactOutputMultiHop(AMOUNT_OUT, MAX_AMOUNT_IN);
        uint256 w1 = _WETH.balanceOf(address(this));
        uint256 d1 = _DAI.balanceOf(address(this));

        assertLt(w1, w0, "no WETH decrease");
        assertGt(d1, d0, "no DAI increase");
        assertEq(
            _WETH.balanceOf(address(multiswap)),
            0,
            "WETH balance of swap is not equal to  0"
        );
        assertEq(
            _DAI.balanceOf(address(multiswap)),
            0,
            "DAI balance of swap is not equal to 0"
        );
    }
}
