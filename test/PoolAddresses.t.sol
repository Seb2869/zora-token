// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";

import {Zora} from "../src/zora/Zora.sol";
import {IZora} from "../src/zora/IZora.sol";
import {Test} from "forge-std/Test.sol";
import {IImmutableCreate2Factory} from "../src/deployment/IImmutableCreate2Factory.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DeploymentBase} from "../src/deployment/DeploymentBase.sol";

/// @title Provides functions for deriving a pool address from the factory, tokens, and the fee
library PoolAddress {
    bytes32 internal constant POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    /// @notice The identifying key of the pool
    struct PoolKey {
        address token0;
        address token1;
        uint24 fee;
    }

    /// @notice Returns PoolKey: the ordered tokens with the matched fee levels
    /// @param tokenA The first token of a pool, unsorted
    /// @param tokenB The second token of a pool, unsorted
    /// @param fee The fee level of the pool
    /// @return Poolkey The pool details with ordered token0 and token1 assignments
    function getPoolKey(address tokenA, address tokenB, uint24 fee) internal pure returns (PoolKey memory) {
        if (tokenA > tokenB) (tokenA, tokenB) = (tokenB, tokenA);
        return PoolKey({token0: tokenA, token1: tokenB, fee: fee});
    }

    /// @notice Deterministically computes the pool address given the factory and PoolKey
    /// @param factory The Uniswap V3 factory contract address
    /// @param key The PoolKey
    /// @return pool The contract address of the V3 pool
    function computeAddress(address factory, PoolKey memory key) internal pure returns (address pool) {
        require(key.token0 < key.token1);
        pool = address(
            uint160(uint256(keccak256(abi.encodePacked(hex"ff", factory, keccak256(abi.encode(key.token0, key.token1, key.fee)), POOL_INIT_CODE_HASH))))
        );
    }
}

interface IUniswapV3Factory {
    function createPool(address tokenA, address tokenB, uint24 fee) external returns (address pool);
}

contract PoolAddressesTest is Test {
    function testPoolAddresses() public {
        vm.createSelectFork("base", 26990278);

        address factory = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;

        address zora = 0x1111111111166b7FE7bd91427724B487980aFc69;
        address weth = 0x4200000000000000000000000000000000000006;
        address usdc = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

        // 1000 = 0.1%
        // 10000 = 1%
        uint24 fee = 10000;

        PoolAddress.PoolKey memory zoraWeth = PoolAddress.PoolKey({token0: zora, token1: weth, fee: fee});
        address expectedWethPool = PoolAddress.computeAddress(factory, zoraWeth);
        PoolAddress.PoolKey memory zoraUsdc = PoolAddress.PoolKey({token0: zora, token1: usdc, fee: fee});
        address expectedUsdcPool = PoolAddress.computeAddress(factory, zoraUsdc);

        address actualWethPool = IUniswapV3Factory(factory).createPool(zora, weth, fee);
        address actualUsdcPool = IUniswapV3Factory(factory).createPool(zora, usdc, fee);

        assertEq(actualWethPool, expectedWethPool);
        assertEq(actualUsdcPool, expectedUsdcPool);

        console.log("zoraWethPool", expectedWethPool);
        console.log("zoraUsdcPool", expectedUsdcPool);
    }
}
