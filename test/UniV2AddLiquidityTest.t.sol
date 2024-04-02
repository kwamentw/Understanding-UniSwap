// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {IUniswapV2Router} from "../src/UniSwapV2/interface/IUniswapV2Router.sol";
import {IUniswapV2Factory} from "../src/UniSwapV2/interface/IUniswapV2Factory.sol";
import {IERC20} from "../src/UniSwapV2/interface/IERC20.sol";
import {UniV2AddLiquidity} from "../src/UniSwapV2/UniV2AddLiquidity.sol";

IERC20 constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
IERC20 constant USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
IERC20 constant PAIR = IERC20(0x0d4a11d5EEaaC28EC3F61d100daF4d40471f1852);

contract UniV2AddLiquidityTest is Test {
    UniV2AddLiquidity private uni;

    function safeTransferFrom(
        IERC20 token,
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        (bool sent, bytes memory returndata) = address(token).call(
            abi.encodeCall(IERC20.transferFrom, (sender, recipient, amount))
        );
        require(
            sent && (returndata.length == 0 || abi.decode(returndata, (bool))),
            "Transfer from fail"
        );
    }

    function safeApprove(
        IERC20 token,
        address spender,
        uint256 amount
    ) internal {
        (bool sent, bytes memory returnData) = address(token).call(
            abi.encodeCall(IERC20.approve, (spender, amount))
        );

        require(
            sent && (returnData.length == 0 || abi.decode(returnData, (bool))),
            "Approve fail"
        );
    }

    // Add WETH/USDT liquidity  to Uniswap
    function testAddLiquidity() public {
        // Deal test USDT and WETH to this contract
        deal(address(USDT), address(this), 1e6 * 1e6);
        assertEq(
            USDT.balanceOf(address(this)),
            1e6 * 1e6,
            "USDT balance incorrect"
        );
        deal(address(WETH), address(this), 1e6 * 1e18);
        assertEq(
            WETH.balanceOf(address(this)),
            1e6 * 1e18,
            "Weth balance incorrect"
        );

        //Approve uni for transferring
        safeApprove(WETH, address(uni), 1e64);
        safeApprove(USDT, address(uni), 1e64);

        uni.addLiquidity(address(WETH), address(USDT), 1 * 1e18, 3000.05 * 1e6);
        assertGt(PAIR.balanceOf(address(uni)), 0, "pair balance 0");
    }

    function testRemoveLiquidity() public {
        // DEAL LP tokens to uni(main uniswap contract)
        deal(address(PAIR), address(uni), 1e10);
        assertEq(PAIR.balanceOf(address(uni)), 1e10, "LP tokens balance = 0");
        assertEq(USDT.balanceOf(address(uni)), 0, "USDT balance non-zero");
        assertEq(WETH.balanceOf(address(uni)), 0, "WETH balance non zero");

        uni.removeLiquidity(address(WETH), address(USDT));

        assertEq(PAIR.balanceOf(address(uni)), 0, "LP TOkens balance != zero");
        assertGt(USDT.balanceOf(address(uni)), 0, "USDT balance = 0");
        assertGt(WETH.balanceOf(address(uni)), 0, "WETH bal = 0");
    }
}
