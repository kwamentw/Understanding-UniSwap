// SPDX-License-Identifier:MIT
pragma solidity 0.8.20;

import {IERC20} from "./interfaces/IERC20.sol";
import {IUniswapV3Pool} from "./interfaces/IUniSwapV3Pool.sol";

contract UniswapV3flashSwap {
    struct FlashCallBackData {
        uint256 amount0;
        uint256 amount1;
        address caller;
    }
    IUniswapV3Pool private immutable pool;
    IERC20 private immutable token0;
    IERC20 private immutable token1;

    constructor(address _pool) {
        pool = IUniswapV3Pool(_pool);
        token0 = IERC20(pool.token0());
        token1 = IERC20(pool.token1());
    }

    function flash(uint256 amount0, uint256 amount1) external {
        bytes memory data = abi.encode(
            FlashCallBackData({
                amount0: amount0,
                amount1: amount1,
                caller: msg.sender
            })
        );
        pool.flash(address(this), amount0, amount1, data);
    }

    function uniswapV3FlashCallback(
        // Pool fee X amount requested
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external {
        require(msg.sender == address(pool), "not authorised");
        FlashCallBackData memory decoded = abi.decode(
            data,
            (FlashCallBackData)
        );

        //write custom code here
        if (fee0 > 0) {
            token0.transferFrom(decoded.caller, address(this), fee0);
        }
        if (fee1 > 0) {
            token1.transferFrom(decoded.caller, address(this), fee1);
        }

        // repay borrowed + fees
        if (fee0 > 0) {
            token0.transfer(address(pool), decoded.amount0 + fee0);
        }
        if (fee1 > 0) {
            token1.transfer(address(pool), decoded.amount1 + fee1);
        }
    }
}
