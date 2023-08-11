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

contract VaultDepositTwoStratsTest is Setup, VaultRoles {

    IVault vault = IVault(0x7E1b3646cC641A9C4442E5EC5814789c64D19B88);
    address manager = vault.role_manager();
    IStrategyInterface strategy2;

    function setUp() public override {
        super.setUp();

        // Deploy first strat
        address _wethDaiPool = 0x312Ec1e1a74d66eA4012680351b61c02F67003aC;
        string memory _name = "weth/dai";
        strategy = IStrategyInterface(setUpStrategy(_wethDaiPool, _name));
        factory = strategy.FACTORY();

        // Deploy second strat
        address _yfiDaiPool = 0x6a9Cfcd483C5394b2A5094bF7f478eb79992B032;
        strategy2 = IStrategyInterface(setUpStrategy(_yfiDaiPool, "yfi/dai"));

        vm.prank(manager);
        vault.transfer_role_manager(management);

        vm.startPrank(management);
        vault.accept_role_manager();

        vault.set_role(management, ADD_STRATEGY_MANAGER);
        vault.add_strategy(address(strategy));
        vault.add_strategy(address(strategy2));

        vault.set_role(management, DEPOSIT_LIMIT_MANAGER);
        vault.set_deposit_limit(2**256-1);

        vault.set_role(management, MAX_DEBT_MANAGER);
        vault.update_max_debt_for_strategy(address(strategy), 2**256-1);
        vault.update_max_debt_for_strategy(address(strategy2), 2**256-1);

        vault.set_role(management, DEBT_MANAGER);
        vm.stopPrank();
    }

    function test_profit_two_strats_through_vault(
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

        vm.startPrank(management);

        uint256 _amount_strat1 = _amount/2;
        uint256 _amount_strat2 = _amount-_amount_strat1;

        vault.update_debt(address(strategy), _amount_strat1);
        vault.update_debt(address(strategy2), _amount_strat2);

        // Add liquidity and check totalAssets, totalDebt and idle values are ok
        strategy.addLiquidity(_amount_strat1, 1);
        strategy2.addLiquidity(_amount_strat2, 1);

        strategy.report();
        strategy2.report();

        checkStrategyTotals(strategy, _amount_strat1, _amount_strat1, 0);
        checkStrategyTotals(strategy2, _amount_strat2, _amount_strat2, 0);

        // Remove the liquidity and airdrop profit
        strategy.removeLiquidity(_amount_strat1, 1);
        strategy2.removeLiquidity(_amount_strat2, 1);

        uint256 toAirdrop = (_amount * _profitFactor) / MAX_BPS;
        airdrop(asset, address(strategy), toAirdrop);
        airdrop(asset, address(strategy2), toAirdrop);
        console.log("airdropping", toAirdrop);

        (uint256 profit1, uint256 loss1) = strategy.report();
        (uint256 profit2, uint256 loss2) = strategy2.report();

        uint256 _expectedTotal1 = _amount_strat1+toAirdrop;
        uint256 _expectedTotal2 = _amount_strat2+toAirdrop;
        checkStrategyTotals(strategy, _amount_strat1+toAirdrop, 0, _expectedTotal1);
        checkStrategyTotals(strategy2, _amount_strat2+toAirdrop, 0, _expectedTotal2);

        // Check return Values
        assertGe(profit1, toAirdrop, "!profit1");
        assertGe(profit2, toAirdrop, "!profit2");
        assertEq(loss1, 0, "!loss1");
        assertEq(loss2, 0, "!loss2");

        skip(strategy.profitMaxUnlockTime());
        skip(strategy2.profitMaxUnlockTime());

        vm.stopPrank();

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
