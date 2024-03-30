// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC721Receiver} from "./interfaces/IERC721Receiver.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {INonfungiblePositionManager} from "./interfaces/INonfungiblePositionManager.sol";

address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

contract UniswapV3Liquidity {
    IERC20 private constant _DAI = IERC20(DAI);
    IWETH private constant _WETH = IWETH(WETH);

    int24 private constant MIN_TICK = -887272;
    int24 private constant MAX_TICK = -MIN_TICK;
    int24 private constant TICK_SPACING = 60;

    INonfungiblePositionManager public nonfungiblePositionManager =
        INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata
    ) external returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function mintNewPosition(
        uint256 amount0ToAdd,
        uint256 amount1ToAdd
    )
        external
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        _DAI.transferFrom(msg.sender, address(this), amount0ToAdd);
        _WETH.transferFrom(msg.sender, address(this), amount1ToAdd);

        _DAI.approve(address(nonfungiblePositionManager), amount0ToAdd);
        _WETH.approve(address(nonfungiblePositionManager), amount1ToAdd);

        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: DAI,
                token1: WETH,
                fee: 3000,
                tickLower: (MIN_TICK / TICK_SPACING) * TICK_SPACING,
                tickUpper: (MAX_TICK / TICK_SPACING) * TICK_SPACING,
                amount0Desired: amount0ToAdd,
                amount1Desired: amount1ToAdd,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            });

        (tokenId, liquidity, amount0, amount1) = nonfungiblePositionManager
            .mint(params);

        if (amount0 < amount0ToAdd) {
            _DAI.approve(address(nonfungiblePositionManager), 0);
            uint256 refund0 = amount0ToAdd - amount0;
            _DAI.transfer(msg.sender, refund0);
        }

        if (amount1 < amount1ToAdd) {
            _DAI.approve(address(nonfungiblePositionManager), 0);
            uint256 refund1 = amount1ToAdd - amount1;
            _DAI.transfer(msg.sender, refund1);
        }
    }

    function collectAllFees(
        uint256 tokenId
    ) external returns (uint256 amount0, uint256 amount1) {
        INonfungiblePositionManager.CollectParams
            memory params = INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });

        (amount0, amount1) = nonfungiblePositionManager.collect(params);
    }

    function increaseLiquidityCurrentRange(
        uint256 tokenId,
        uint256 amount0ToAdd,
        uint256 amount1ToAdd
    ) external returns (uint128 liquidity, uint256 amount0, uint256 amount1) {
        _DAI.transferFrom(msg.sender, address(this), amount0ToAdd);
        _WETH.transferFrom(msg.sender, address(this), amount1ToAdd);

        _DAI.approve(address(nonfungiblePositionManager), amount0ToAdd);
        _WETH.approve(address(nonfungiblePositionManager), amount1ToAdd);

        INonfungiblePositionManager.IncreaseLiquidityParams
            memory params = INonfungiblePositionManager
                .IncreaseLiquidityParams({
                    tokenId: tokenId,
                    amount0Desired: amount0ToAdd,
                    amount1Desired: amount1ToAdd,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                });

        (liquidity, amount0, amount1) = nonfungiblePositionManager
            .increaseLiquidity(params);
    }

    function decreaseLiquidityCurrentRange(
        uint256 tokenId,
        uint128 liquidity
    ) external returns (uint256 amount0, uint256 amount1) {
        INonfungiblePositionManager.DecreaseLiquidityParams
            memory params = INonfungiblePositionManager
                .DecreaseLiquidityParams({
                    tokenId: tokenId,
                    liquidity: liquidity,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                });

        (amount0, amount1) = nonfungiblePositionManager.decreaseLiquidity(
            params
        );
    }
}
