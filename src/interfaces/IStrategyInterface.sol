// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.18;

import {IStrategy} from "@tokenized-strategy/interfaces/IStrategy.sol";

interface IStrategyInterface is IStrategy {
  function addLiquidity(uint256 _amount, uint256 _index) external;

  function removeLiquidity(uint256 _amount, uint256 _index) external;

  function sweep() external;

  function pool() external view returns (address);
}
