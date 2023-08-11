// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/console.sol";
import {Setup} from "./utils/Setup.sol";
import {IStrategyInterface} from "../../src/interfaces/IStrategyInterface.sol";

contract OperationTest is Setup {
    function setUp() public override {
        super.setUp();
        address _wethDaiPool = 0x312Ec1e1a74d66eA4012680351b61c02F67003aC;
        string memory _name = "weth/dai";
        strategy = IStrategyInterface(setUpStrategy(_wethDaiPool, _name));
        factory = strategy.FACTORY();
    }

    function testSetupStrategyOK() public {
        console.log("address of strategy", address(strategy));
        assertTrue(address(0) != address(strategy));
        assertEq(strategy.asset(), address(asset));
        assertEq(strategy.management(), management);
        assertEq(strategy.performanceFeeRecipient(), performanceFeeRecipient);
        assertEq(strategy.keeper(), keeper);
        assertEq(strategy.pool(), 0x312Ec1e1a74d66eA4012680351b61c02F67003aC);
    }

    function test_operation(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        // TODO: Implement logic so totalDebt is _amount and totalIdle = 0.
        checkStrategyTotals(strategy, _amount, 0, _amount);

        // Earn Interest
        skip(1 days);

        // Report profit
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        // Check return Values
        assertGe(profit, 0, "!profit");
        assertEq(loss, 0, "!loss");

        skip(strategy.profitMaxUnlockTime());

        uint256 balanceBefore = asset.balanceOf(user);

        // Withdraw all funds
        vm.prank(user);
        strategy.redeem(_amount, user, user);

        assertGe(
            asset.balanceOf(user),
            balanceBefore + _amount,
            "!final balance"
        );
    }

    function test_profitableReport(
        uint256 _amount,
        uint16 _profitFactor
    ) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);
        _profitFactor = uint16(bound(uint256(_profitFactor), 10, MAX_BPS));

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        // Add liquidity and check totalAssets, totalDebt and idle values are ok
        vm.prank(management);
        strategy.addLiquidity(_amount, 1);
        vm.prank(management);
        strategy.report();
        checkStrategyTotals(strategy, _amount, _amount, 0);

        console.log("after check");
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
        vm.prank(user);
        strategy.redeem(_amount, user, user);

        assertGe(
            asset.balanceOf(user),
            balanceBefore + _amount,
            "!final balance"
        );
    }

}
