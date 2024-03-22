// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.20;

import {Tick} from "./lib/Tick.sol";
import {TickMath} from "./lib/TickMath.sol";
import {Positionn} from "./lib/Positionn.sol";
import {SafeCast} from "./lib/SafeCast.sol";
import {IERC20} from "./interfaces/IERC20.sol";

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
        return (positions[bytes32(0)], 0, 0);
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
}
