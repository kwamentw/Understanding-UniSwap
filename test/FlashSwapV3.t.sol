// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {UniswapV3flashSwap, IERC20} from "../src/UniswapV3FlashSwap.sol";

contract UniswapV3FlashTest is Test {
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    // DAI/WETH 0.3% fee
    address constant POOL = 0xC2e9F25Be6257c210d7Adf0D4Cd6E3E881ba25f8;
    uint24 constant POOL_FEE = 3000;

    IERC20 private constant _WETH = IERC20(WETH);
    IERC20 private constant _DAI = IERC20(DAI);
    UniswapV3flashSwap private uni;
    address constant USER = address(99);

    function setUp() public {
        uni = new UniswapV3flashSwap(POOL);

        deal(DAI, USER, 1e6 * 1e18);
        vm.prank(USER);
        _DAI.approve(address(uni), type(uint256).max);
    }

    function testFlashSwap() public {
        uint256 dai_before = _DAI.balanceOf(USER);
        vm.prank(USER);
        uni.flash(1e6 * 1e18, 0);
        uint256 dai_after = _DAI.balanceOf(USER);
        uint256 fee = dai_before - dai_after;
        console2.log("Previous DAI amount:", dai_before);
        console2.log("DAI fee: ", fee);
        console2.log("DAI amount AFter:", dai_after);
    }
}
