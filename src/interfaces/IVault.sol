// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.18;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

interface IVault is IERC4626 {
    struct StrategyParams {
        uint256 activation;
        uint256 lastReport;
        uint256 currentDebt;
        uint256 maxDebt;
    }

    function strategies(
        address _strategy
    ) external view returns (StrategyParams memory);

    function set_role(address, uint256) external;

    function roles(address _address) external view returns (uint256);

    function role_manager() external view returns (address);

    function profitMaxUnlockTime() external view returns (uint256);

    function add_strategy(address) external;

    function update_max_debt_for_strategy(address, uint256) external;

    function update_debt(address, uint256) external;

    function process_report(
        address _strategy
    ) external returns (uint256, uint256);

    function set_deposit_limit(uint256) external;

    function shutdown_vault() external;

    function shutdown() external view returns (bool);

    function transfer_role_manager(address role_manager) external;
    function accept_role_manager() external;
}
