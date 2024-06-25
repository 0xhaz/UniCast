// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.25;

import {BaseHook} from "v4-periphery/BaseHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {UniCastVolatilityFee} from "./UniCastVolatilityFee.sol";
import {UniCastVault} from "./UniCastVault.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {IUniCastOracle} from "./interface/IUnicastOracle.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {CurrencyLibrary, Currency} from "v4-core/types/Currency.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {UniswapV4ERC20} from "v4-periphery/libraries/UniswapV4ERC20.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {console} from "forge-std/console.sol";

contract UniCastHook is UniCastVolatilityFee, UniCastVault, BaseHook {
    using LPFeeLibrary for uint24;
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    /**
     * @dev Constructor for the UniCastHook contract
     * @param _poolManager The address of the pool manager
     * @param _oracle The address of the volatility oracle
     */
    constructor(IPoolManager _poolManager, IUniCastOracle _oracle, int24 initialMinTick, int24 initialMaxTick)
        UniCastVault(_poolManager, _oracle, initialMinTick, initialMaxTick)
        UniCastVolatilityFee(_poolManager, _oracle)
        BaseHook(_poolManager)
    {}

    /**
     * @dev Returns the permissions for the hook
     * @return A Hooks.Permissions struct with the permissions
     */
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            afterInitialize: false,
            beforeAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterAddLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    /**
     * @dev Hook that is called before pool initialization
     * @param key The pool key
     * @return a bytes4 selector
     */
    function beforeInitialize(address, PoolKey calldata key, uint160, bytes calldata)
        external
        override
        returns (bytes4)
    {
        if (!key.fee.isDynamicFee()) revert MustUseDynamicFee();
        PoolId poolId = key.toId();
        string memory tokenSymbol = string(
            abi.encodePacked(
                "UniV4",
                "-",
                IERC20Metadata(Currency.unwrap(key.currency0)).symbol(),
                "-",
                IERC20Metadata(Currency.unwrap(key.currency1)).symbol(),
                "-",
                Strings.toString(uint256(key.fee))
            )
        );

        UniswapV4ERC20 poolToken = new UniswapV4ERC20(tokenSymbol, tokenSymbol);
        poolInfos[poolId] = PoolInfo({hasAccruedFees: false, poolToken: poolToken});

        return IHooks.beforeInitialize.selector;
    }

    // /**
    //  * @dev Hook that is called before adding liquidity
    //  * @param sender The address of the sender
    //  * @return a bytes4 selector
    //  */
    // function beforeAddLiquidity(
    //     address sender,
    //     PoolKey calldata,
    //     IPoolManager.ModifyLiquidityParams calldata,
    //     bytes calldata
    // ) external view override returns (bytes4) {
    //     if (sender != address(this)) revert SenderMustBeHook();
    //     return IHooks.beforeAddLiquidity.selector;
    // }

    /**
     * @dev Hook that is called before a swap
     * @param key The pool key
     * @return A tuple containing a bytes4 selector, a BeforeSwapDelta, and a uint24 fee
     */
    function beforeSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata, bytes calldata)
        external
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        PoolId poolId = key.toId();
        uint24 fee = getFee(poolId);

        (,,, uint24 currentFee) = poolManagerFee.getSlot0(poolId);
        if (currentFee != fee) poolManagerFee.updateDynamicLPFee(key, fee);

        if (!poolInfos[poolId].hasAccruedFees) {
            PoolInfo storage pool = poolInfos[poolId];
            pool.hasAccruedFees = true;
        }

        return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    /**
     * @dev Hook that is called after a swap
     * @param poolKey The pool key
     * @return A tuple containing a bytes4 selector and a int128 value
     */
    function afterSwap(
        address,
        PoolKey calldata poolKey,
        IPoolManager.SwapParams calldata,
        BalanceDelta,
        bytes calldata hookData
    ) external override returns (bytes4, int128) {
        bool firstSwap = hookData.length == 0 || abi.decode(hookData, (bool));
        if (firstSwap) {
            autoRebalance(poolKey);
        }

        return (IHooks.afterSwap.selector, 0);
    }

    /**
     * @dev Callback function for unlocking the vault
     * @param rawData The raw data to pass to the callback
     * @return The result of the callback
     */
    function unlockCallback(bytes calldata rawData) external override returns (bytes memory) {
        return _unlockVaultCallback(rawData);
    }
}
