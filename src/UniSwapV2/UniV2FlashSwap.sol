//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "./interface/IERC20.sol";
import {IUniswapV2Callee} from "./interface/IUniswapV2Callee.sol";
import {IUniswapV2Factory} from "./interface/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "./interface/IUniswapV2Pair.sol";
import {IWETH} from "./interface/IWETH.sol";

contract UniV2FlashSwap is IUniswapV2Callee {
    address private constant UNISWAP_V2_FACTORY =
        0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address private constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    IUniswapV2Factory private constant factory =
        IUniswapV2Factory(UNISWAP_V2_FACTORY);

    IERC20 private constant _WETH = IERC20(WETH);
    IUniswapV2Pair private immutable pair;

    // For this example store the amount to repay
    uint256 public amountToRepay;

    constructor() {
        pair = IUniswapV2Pair(factory.getPair(DAI, WETH));
    }

    function flashSwap(uint256 wethAmount) external {
        // we need to pass data to trigger uniswapV2Call
        bytes memory data = abi.encode(WETH, msg.sender);

        //amount0Out is DAI, amount1Out is WETH
        pair.swap(0, wethAmount, address(this), data);
    }

    //this function is called by the DAI/WETH pair contract
    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        require(msg.sender == address(pair), "not pair");
        require(sender == address(this), "not sender");

        (address tokenBorrow, address caller) = abi.decode(
            data,
            (address, address)
        );

        // Your custom code//// code to arbitrage
        require(tokenBorrow == WETH, "Token borrow is not equal to WETH");

        // about 0.3% of fee +1 to round up
        uint256 fee = (amount1 * 3) / 997 + 1;
        amountToRepay = amount1 + fee;

        //GEtting flash swap fee from caller
        _WETH.transfer(address(pair), amountToRepay);
    }
}
