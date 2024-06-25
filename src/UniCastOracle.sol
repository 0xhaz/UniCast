// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.25;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {IUniCastOracle, LiquidityData} from "./interface/IUnicastOracle.sol";

contract UniCastOracle is Ownable, IUniCastOracle {
    uint24 public immutable baseFee; // 500 = 0.05%
    address public keeper;

    event KeeperUpdated(address indexed newKeeper);
    event FeeChanged(PoolId poolId, uint256 fee);
    event LiquidityChanged(PoolId poolId, LiquidityData);

    error Unauthorized();

    mapping(PoolId => int24) public feeAdditional; // could be less than base fee
    mapping(PoolId => LiquidityData) public liquidityData;

    modifier onlyKeeper() {
        if (msg.sender != keeper) revert Unauthorized();
        _;
    }

    /**
     * @dev Constructor to initialize the UniCastOracle contract
     * @param _keeper The address of the keeper
     */
    constructor(address _keeper, uint24 _baseFee) Ownable(_keeper) {
        keeper = _keeper;
        baseFee = _baseFee;
    }

    /**
     * @dev Sets the liquidity data for a given pool
     * @param _poolId The ID of the pool
     * @param _tickLower The lower tick of the liquidity
     * @param _tickUpper The upper tick of the liquidity
     */
    function setLiquidityData(PoolId _poolId, int24 _tickLower, int24 _tickUpper) external onlyKeeper {
        liquidityData[_poolId] = LiquidityData({tickLower: _tickLower, tickUpper: _tickUpper});

        emit LiquidityChanged(_poolId, liquidityData[_poolId]);
    }

    /**
     * @dev Gets the liquidity data for a given pool
     * @param _poolId The ID of the pool
     * @return LiquidityData The liquidity data
     */
    function getLiquidityData(PoolId _poolId) external view returns (LiquidityData memory) {
        return liquidityData[_poolId];
    }

    /**
     * @dev This fee can be set as part of a dutch auction
     * @dev Sets the implied volatility fee for a given pool
     * @param _fee The new implied volatility fee
     */
    function setFee(PoolId _poolId, uint24 _fee) external onlyKeeper {
        feeAdditional[_poolId] = int24(_fee) - int24(baseFee);
        emit FeeChanged(_poolId, _fee);
    }

    /**
     * @dev Updates the keeper address
     * @param _newKeeper the address of the new keeper
     */
    function updateKeeper(address _newKeeper) external onlyKeeper {
        keeper = _newKeeper;
        emit KeeperUpdated(_newKeeper);
    }

    /**
     * @dev Gets the current implied volatility
     * @return The current implied volatility
     */
    function getFee(PoolId poolId) external view returns (uint24) {
        return uint24(feeAdditional[poolId] + int24(baseFee));
    }
}
