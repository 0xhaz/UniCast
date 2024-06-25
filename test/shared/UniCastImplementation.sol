// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.25;

import {BaseHook} from "v4-periphery/BaseHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks, IHooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {UniCastHook} from "src/UniCastHook.sol";
import {IUniCastOracle} from "src/interface/IUnicastOracle.sol";

contract UniCastImplementation is UniCastHook {
    constructor(
        IPoolManager _poolManager,
        IUniCastOracle _oracle,
        UniCastHook addressToEtch,
        int24 initialMinTick,
        int24 initialMaxTick
    ) UniCastHook(_poolManager, _oracle, initialMinTick, initialMaxTick) {
        Hooks.validateHookPermissions(addressToEtch, getHookPermissions());
    }

    // make this a no-op in testing
    function validateHookAddress(BaseHook _this) internal pure override {
        // no-op
    }
}
