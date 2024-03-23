// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.20;

library Positionn {
    /// @notice Cannot update a position with no liquidity
    error CannotUpdateEmptyPosition();

    // info stored for each user's position
    struct Info {
        // the amount of liquidity owned by this position
        uint128 liquidity;
        // fee growth per unit of liquidity as of the last update to liquidity or fees owed
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        // the fees owed to the position owner in token0/token1
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    function get(
        mapping(bytes32 => Info) storage self,
        address owner,
        int24 tickLower,
        int24 tickUpper
    ) internal view returns (Positionn.Info storage position) {
        position = self[
            keccak256(abi.encodePacked(owner, tickLower, tickUpper))
        ];
    }

    function update(
        Info storage self,
        int128 liquidityDelta,
        uint256 feeGrowthInside0X128,
        uint256 feeGrowthInside1X128
    ) internal {
        Info memory _self = self;
        if (liquidityDelta == 0) {
            require(_self.liquidity > 0, "0 Liquidity");
        }

        if (liquidityDelta != 0) {
            self.liquidity = liquidityDelta < 0
                ? _self.liquidity - uint128(-liquidityDelta)
                : _self.liquidity + uint128(liquidityDelta);
        }
    }
}
