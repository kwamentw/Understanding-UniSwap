//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {UniswapV3Liquidity} from "../src/UniswapV3Liquidity.sol";
import {IWETH, IERC20} from "../src/interfaces/IWETH.sol";

address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

contract UniswapV3LiquidityTest is Test {
    IWETH private constant _WETH = IWETH(WETH);
    IERC20 private constant _DAI = IERC20(DAI);

    address private constant DAI_WHALE =
        0xe81D6f03028107A20DBc83176DA82aE8099E9C42;

    UniswapV3Liquidity private uni = new UniswapV3Liquidity();

    function setUp() public {
        vm.prank(DAI_WHALE);
        _DAI.transfer(address(this), 20 * 1e18);

        _WETH.deposit{value: 2 * 1e18}();

        _DAI.approve(address(uni), 20 * 1e18);
        _WETH.approve(address(uni), 2e18);
    }

    function testUniV3Liquidity() public {
        //Track total liquidity
        uint128 liquidity;

        //Mint new position
        uint256 daiAmount = 10 * 1e18;
        uint256 wethAmount = 1e18;
        (
            uint256 tokenId,
            uint128 liquidityDelta,
            uint256 amount0,
            uint256 amount1
        ) = uni.mintNewPosition(daiAmount, wethAmount);
        liquidity += liquidityDelta;

        console2.log("---------MINT-NEW-POSITION----------");
        console2.log("tokenId: ", tokenId);
        console2.log("Liquidity: ", liquidity);
        console2.log("Amount 0: ", amount0);
        console2.log("Amount 1: ", amount1);

        // _____collect fees_____
        (uint256 fee0, uint256 fee1) = uni.collectAllFees(tokenId);
        console2.log("------------COLLECT-FEES--------------");
        console2.log("fee0: ", fee0);
        console2.log("fee1: ", fee1);

        // ________increase liquidity________
        uint256 daiAmountToAdd = 5 * 1e18;
        uint256 wethAmountToAdd = 1e18;

        (liquidityDelta, amount0, amount1) = uni.increaseLiquidityCurrentRange(
            tokenId,
            daiAmountToAdd,
            wethAmountToAdd
        );
        liquidity += liquidityDelta;

        console2.log("------INCREASE-LIQUIDITY-------");
        console2.log("liquidity: ", liquidity);
        console2.log("amount 0: ", amount0);
        console2.log("amount 1: ", amount1);

        // ______decrease liquidity_____
        (amount0, amount1) = uni.decreaseLiquidityCurrentRange(
            tokenId,
            liquidity
        );
        console2.log("-------DECREASE-LiQUIDITY-------");
        console2.log("amount 0: ", amount0);
        console2.log("amount 1: ", amount1);
    }
}
