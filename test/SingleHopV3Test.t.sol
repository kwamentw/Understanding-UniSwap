// SPDX-License-Identifier:MIT
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {UniV3SingleHopSwap} from "../src/SingleSwapV3.sol";
import {IWETH} from "../src/interfaces/IWETH.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {ISwapRouter02} from "../src/interfaces/ISwapRouter02.sol";

contract UniV3SingleSwapTest is Test {
    address private constant SWAP_ROUTER_02 =
        0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address private constant DAI_WETH_POOL_3000 =
        0xC2e9F25Be6257c210d7Adf0D4Cd6E3E881ba25f8;

    IWETH private constant _WETH = IWETH(WETH);
    IERC20 private constant _DAI = IERC20(DAI);

    UniV3SingleHopSwap private singleswap;

    uint256 private constant AMOUNT_IN = 1e18;
    uint256 private constant AMOUNT_OUT = 50 * 1e18;
    uint256 private constant MAX_AMOUNT_IN = 1e18;

    function setUp() public {
        singleswap = new UniV3SingleHopSwap();
        _WETH.deposit{value: AMOUNT_IN + MAX_AMOUNT_IN}();
        _WETH.approve(address(singleswap), type(uint256).max);
    }

    function test_swapExactInputSingleHop() public {
        singleswap.swapExactInputSingleHop(AMOUNT_IN, 1);
        uint256 d1 = _DAI.balanceOf(address(this));
        assertGt(d1, 0, "DAI balance is 0");
    }

    function test_swapExactOutputSingleHop() public {
        uint256 w0 = _WETH.balanceOf(address(this));
        uint256 d0 = _DAI.balanceOf(address(this));
        singleswap.swapExactOutputSingleHop(AMOUNT_OUT, MAX_AMOUNT_IN);
        uint256 w1 = _WETH.balanceOf(address(this));
        uint256 d1 = _DAI.balanceOf(address(this));

        assertLt(w1, w0, "no WETH decrease");
        assertGt(d1, d0, "no DAI increase");
        assertEq(
            _WETH.balanceOf(address(singleswap)),
            0,
            "WETH balance of swap is not equal to 0"
        );
        assertEq(
            _DAI.balanceOf(address(singleswap)),
            0,
            "DAI balance of swap is not equal to 0"
        );
    }
}
