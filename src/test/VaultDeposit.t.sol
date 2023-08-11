// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/console.sol";
import {Setup} from "./utils/Setup.sol";
import {IVault} from "../../src/interfaces/IVault.sol";
import {IStrategyInterface} from "../../src/interfaces/IStrategyInterface.sol";

contract VaultRoles {
  uint256 public constant ADD_STRATEGY_MANAGER = 1;
  uint256 public constant REVOKE_STRATEGY_MANAGER = 2;
  uint256 public constant FORCE_REVOKE_MANAGER = 4;
  uint256 public constant ACCOUNTANT_MANAGER = 8;
  uint256 public constant QUEUE_MANAGER = 16;
  uint256 public constant REPORTING_MANAGER = 32;
  uint256 public constant DEBT_MANAGER = 64;
  uint256 public constant MAX_DEBT_MANAGER = 128;
  uint256 public constant DEPOSIT_LIMIT_MANAGER = 256;
  uint256 public constant MINIMUM_IDLE_MANAGER = 512;
  uint256 public constant PROFIT_UNLOCK_MANAGER = 1024;
  uint256 public constant DEBT_PURCHASER = 2048;
  uint256 public constant EMERGENCY_MANAGER = 4096;
}

contract VaultDepositTest is Setup, VaultRoles {

    IVault vault = IVault(0x7E1b3646cC641A9C4442E5EC5814789c64D19B88);
    address manager = vault.role_manager();

    function setUp() public override {
        super.setUp();

        address _wethDaiPool = 0x312Ec1e1a74d66eA4012680351b61c02F67003aC;
        string memory _name = "weth/dai";
        strategy = IStrategyInterface(setUpStrategy(_wethDaiPool, _name));
        factory = strategy.FACTORY();

        vm.prank(manager);
        vault.transfer_role_manager(management);

        vm.startPrank(management);
        vault.accept_role_manager();
        vault.set_role(management, ADD_STRATEGY_MANAGER);
        vault.add_strategy(address(strategy));

        vault.set_role(management, DEPOSIT_LIMIT_MANAGER);
        vault.set_deposit_limit(2**256-1);

        vault.set_role(management, MAX_DEBT_MANAGER);
        vault.update_max_debt_for_strategy(address(strategy), 2**256-1);

        vault.set_role(management, DEBT_MANAGER);

        vm.stopPrank();
    }

    function test_profit_through_vault(
        uint256 _amount,
        uint16 _profitFactor
    ) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);
        _profitFactor = uint16(bound(uint256(_profitFactor), 10, MAX_BPS));

        // Deposit into vault
        airdrop(asset, user, _amount);
        vm.prank(user);
        asset.approve(address(vault), _amount);

        vm.prank(user);
        vault.deposit(_amount, user);

        vm.prank(management);
        vault.update_debt(address(strategy), _amount);

        // Add liquidity and check totalAssets, totalDebt and idle values are ok
        vm.prank(management);
        strategy.addLiquidity(_amount, 1);
        vm.prank(management);
        strategy.report();
        checkStrategyTotals(strategy, _amount, _amount, 0);

        // Remove the liquidity and airdrop profit
        vm.prank(management);
        strategy.removeLiquidity(_amount, 1);
        uint256 toAirdrop = (_amount * _profitFactor) / MAX_BPS;
        airdrop(asset, address(strategy), toAirdrop);
        vm.prank(management);
        (uint256 profit, uint256 loss) = strategy.report();

        uint256 _expectedTotal = _amount+toAirdrop;
        checkStrategyTotals(strategy, _amount+toAirdrop, 0, _expectedTotal);

        // Check return Values
        assertGe(profit, toAirdrop, "!profit");
        assertEq(loss, 0, "!loss");

        skip(strategy.profitMaxUnlockTime());

        uint256 balanceBefore = asset.balanceOf(user);

        // Withdraw all funds
        uint256 vaultShares = vault.balanceOf(user);
        vm.prank(user);
        vault.redeem(vaultShares, user, user);

        assertGe(
            asset.balanceOf(user),
            balanceBefore + _amount,
            "!final balance"
        );
    }


}
