// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.20;

import {Tick} from "./lib/Tick.sol";
import {TickMath} from "./lib/TickMath.sol";
import {Positionn} from "./lib/Positionn.sol";
import {SafeCast} from "./lib/SafeCast.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {SqrtPriceMath} from "./lib/SqrtPriceMath.sol";

function checkTicks(int24 tickLower, int24 tickUpper) pure {
    require(tickLower < tickUpper);
    require(tickLower >= TickMath.MIN_TICK);
    require(tickUpper <= TickMath.MAX_TICK);
}

contract Clamm {
    using SafeCast for uint256;
    using SafeCast for int256;
    using Tick for mapping(int24 => Tick.Info);
    using Positionn for mapping(bytes32 => Positionn.Info);
    using Positionn for Positionn.Info;

    address public immutable token0;
    address public immutable token1;

    uint24 public immutable fee;
    int24 public immutable tickSpacing;
    uint128 public immutable maxLiquidityPerTick;

    struct Slot0 {
        uint160 sqrtPriceX96;
        int24 tick;
        bool unlocked;
    }

    Slot0 public slot0;
    uint256 public feeGrowthGlobal0X128;
    uint256 public feeGrowthGlobal1X128;
    uint128 public liquidity;
    mapping(int24 => Tick.Info) public ticks;
    mapping(bytes32 => Positionn.Info) public positions;

    modifier lock() {
        require(slot0.unlocked, "locked");
        slot0.unlocked = false;
        _;
        slot0.unlocked = true;
    }

    constructor(
        address _token0,
        address _token1,
        uint24 _fee,
        int24 _tickSpacing
    ) {
        token0 = _token0;
        token1 = _token1;
        fee = _fee;
        tickSpacing = _tickSpacing;
        maxLiquidityPerTick = Tick.tickSpacingToMaxLiquidityPerTick(
            _tickSpacing
        );
    }

    function initialize(uint160 sqrtPriceX96) external {
        require(slot0.sqrtPriceX96 == 0, "already initialized");
        int24 tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
        slot0 = Slot0({sqrtPriceX96: sqrtPriceX96, tick: tick, unlocked: true});
    }

    function _updatePositionn(
        address owner,
        int24 tickLower,
        int24 tickUpper,
        int128 liquidityDelta,
        int24 tick
    ) private returns (Positionn.Info storage position) {
        position = positions.get(owner, tickLower, tickUpper);

        // TODO:FEES
        uint256 _feeGrowthGlobal0x128 = 0;
        uint256 _feeGrowthGlobal1x128 = 0;

        bool flippedUpper;
        bool flippedLower;
        if (liquidityDelta != 0) {
            flippedLower = ticks.update(
                tickLower,
                tick,
                liquidityDelta,
                _feeGrowthGlobal0x128,
                _feeGrowthGlobal1x128,
                false,
                maxLiquidityPerTick
            );

            flippedUpper = ticks.update(
                tickUpper,
                tick,
                liquidityDelta,
                _feeGrowthGlobal0x128,
                _feeGrowthGlobal1x128,
                true,
                maxLiquidityPerTick
            );
        }

        // TODO Fees
        position.update(liquidityDelta, 0, 0);

        if (liquidityDelta < 0) {
            if (flippedLower) {
                ticks.clear(tickLower);
            }
            if (flippedUpper) {
                ticks.clear(tickUpper);
            }
        }
    }

    struct ModifyPositionParams {
        address owner;
        int24 tickLower;
        int24 tickUpper;
        int128 liquidityDelta;
    }

    function _modifyPosition(
        ModifyPositionParams memory params
    )
        private
        returns (
            Positionn.Info storage position,
            int256 amount0,
            int256 amount1
        )
    {
        checkTicks(params.tickLower, params.tickUpper);
        Slot0 memory _slot0 = slot0;
        position = _updatePositionn(
            params.owner,
            params.tickUpper,
            params.tickLower,
            params.liquidityDelta,
            _slot0.tick
        );

        if (params.liquidityDelta != 0) {
            if (_slot0.tick < params.tickLower) {
                amount0 = SqrtPriceMath.getAmount0Delta(
                    TickMath.getSqrtRatioAtTick(params.tickLower),
                    TickMath.getSqrtRatioAtTick(params.tickUpper),
                    params.liquidityDelta
                );
            } else if (_slot0.tick < params.tickUpper) {
                amount0 = SqrtPriceMath.getAmount0Delta(
                    _slot0.sqrtPriceX96,
                    TickMath.getSqrtRatioAtTick(params.tickUpper),
                    params.liquidityDelta
                );
                amount1 = SqrtPriceMath.getAmount1Delta(
                    TickMath.getSqrtRatioAtTick(params.tickLower),
                    _slot0.sqrtPriceX96,
                    params.liquidityDelta
                );
                liquidity = params.liquidityDelta < 0
                    ? liquidity - uint128(-params.liquidityDelta)
                    : liquidity + uint128(params.liquidityDelta);
            } else {
                amount1 = SqrtPriceMath.getAmount1Delta(
                    TickMath.getSqrtRatioAtTick(params.tickLower),
                    TickMath.getSqrtRatioAtTick(params.tickUpper),
                    params.liquidityDelta
                );
            }
        }
    }

    function mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external lock returns (uint256 amount0, uint256 amount1) {
        require(amount > 0, "amount = 0");
        (, int256 amount0Int, int256 amount1Int) = _modifyPosition(
            ModifyPositionParams({
                owner: recipient,
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidityDelta: int256(uint256(amount)).toInt128()
            })
        );

        amount0 = uint256(amount0Int);
        amount1 = uint256(amount1Int);

        if (amount0 > 0) {
            IERC20(token0).transferFrom(msg.sender, address(this), amount0);
        }
        if (amount1 > 0) {
            IERC20(token1).transferFrom(msg.sender, address(this), amount1);
        }
    }

    function collect(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external lock returns (uint128 amount0, uint128 amount1) {
        Positionn.Info storage position = positions.get(
            msg.sender,
            tickLower,
            tickUpper
        );

        amount0 = amount0Requested > position.tokensOwed0
            ? position.tokensOwed0
            : amount0Requested;
        amount1 = amount1Requested > position.tokensOwed1
            ? position.tokensOwed1
            : amount1Requested;

        if (amount0 > 0) {
            position.tokensOwed0 -= amount0;
            IERC20(token0).transfer(recipient, amount0);
        }

        if (amount1 > 0) {
            position.tokensOwed1 -= amount1;
            IERC20(token1).transfer(recipient, amount1);
        }
    }

    function burn(
        int24 tickLower,
        int24 tickUpper,
        uint256 amount
    ) external lock returns (uint256 amount0, uint256 amount1) {
        (
            Positionn.Info storage position,
            int256 amount0Int,
            int256 amount1Int
        ) = _modifyPosition(
                ModifyPositionParams({
                    owner: msg.sender,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    liquidityDelta: -int256(uint256(amount)).toInt128()
                })
            );

        amount0 = uint256(-amount0Int);
        amount1 = uint256(-amount1Int);

        if (amount0 > 0 || amount1 > 0) {
            (position.tokensOwed0, position.tokensOwed1) = (
                position.tokensOwed0 + uint128(amount0),
                position.tokensOwed1 + uint128(amount1)
            );
        }
    }

    struct SwapCache {
        // liquidity at the begining of the swap
        uint128 liquidityStart;
    }

    // the top level state of the swap
    struct SwapState {
        // the amount remaining to be swapped in/out of the input/output asset
        int256 amountSpecifiedRemaining;
        // the amount already swapped in/out of the output/input asset
        int256 amountCalculated;
        // current sqrt price
        uint160 sqrtPriceX96;
        //the tick  associated with the current price
        int24 tick;
        // the global fee growth of the input token
        uint256 feeGrowthGlobalX128;
        // the current liquidity in range
        uint128 liquidity;
    }

    struct StepComputations {
        // the price at the begining of the step
        uint160 sqrtPriceStartX96;
        // the next tick to swap to from the current tick in the swap direction
        int24 tickNext;
        // whether ticknext is initialised or not
        bool iniitialized;
        // sqrt(price) for the next tick (1/0)
        uint160 sqrtPriceNextX96;
        // how much is being swapped in this step
        uint256 amountIn;
        // how much is swapped out
        uint256 amountOut;
        // how much fee is being paid in
        uint256 feeAmount;
    }

    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96
    ) external lock returns (int256 amount0, int256 amount1) {
        require(amountSpecified != 0);

        Slot0 memory slot0Start = slot0;
        // token 1 | token 0
        // --------|---------
        //        tick
        // <-- zero for one
        require(
            zeroForOne
                ? sqrtPriceLimitX96 < slot0Start.sqrtPriceX96 &&
                    sqrtPriceLimitX96 > TickMath.MIN_SQRT_RATIO
                : sqrtPriceLimitX96 > slot0Start.sqrtPriceX96 &&
                    sqrtPriceLimitX96 < TickMath.MAX_SQRT_RATIO,
            "Invalid sqrt price limit"
        );

        SwapCache memory cache = SwapCache({liquidityStart: liquidity});
        bool exactInput = amountSpecified > 0;
        SwapState memory state = SwapState({
            amountSpecifiedRemaining: amountSpecified,
            amountCalculated: 0,
            sqrtPriceX96: slot0Start.sqrtPriceX96,
            tick: slot0Start.tick,
            feeGrowthGlobalX128: zeroForOne
                ? feeGrowthGlobal0X128
                : feeGrowthGlobal1X128,
            liquidity: cache.liquidityStart
        });
        // TODO
        while (true) {}

        // Update sqrtPriceX96 and tick
        if (state.tick != slot0Start.tick) {
            (slot0.sqrtPriceX96, slot0.tick) = (state.sqrtPriceX96, state.tick);
        } else {
            slot0.sqrtPriceX96 = state.sqrtPriceX96;
        }

        // Update Liquidity
        if (cache.liquidityStart != state.liquidity) {
            liquidity = state.liquidity;
        }

        // Update FeeGrowth
        if (zeroForOne) {
            feeGrowthGlobal0X128 = state.feeGrowthGlobalX128;
        } else {
            feeGrowthGlobal1X128 = state.feeGrowthGlobalX128;
        }

        // Set amount0 and amount1
        // zero for one | exact input |
        //    true      |    true     | amount 0 = specified - remaining (> 0)
        //              |             | amount 1 = calculated            (< 0)
        //    false     |    false    | amount 0 = specified - remaining (< 0)
        //              |             | amount 1 = calculated            (> 0)
        //    false     |    true     | amount 0 = calculated            (< 0)
        //              |             | amount 1 = specified - remaining (> 0)
        //    true      |    false    | amount 0 = calculated            (> 0)
        //              |             | amount 1 = specified - remaining (< 0)

        (amount0, amount1) = zeroForOne == exactInput
            ? (
                amountSpecified - state.amountSpecifiedRemaining,
                state.amountCalculated
            )
            : (
                state.amountCalculated,
                amountSpecified - state.amountSpecifiedRemaining
            );

        if (zeroForOne) {
            if (amount1 < 0) {
                IERC20(token1).transfer(recipient, uint256(-amount1));
                IERC20(token0).transferFrom(
                    msg.sender,
                    address(this),
                    uint256(amount0)
                );
            }
        } else {
            if (amount0 < 0) {
                IERC20(token0).transfer(recipient, uint256(-amount0));
                IERC20(token1).transferFrom(
                    msg.sender,
                    address(this),
                    uint256(amount1)
                );
            }
        }
    }
}
