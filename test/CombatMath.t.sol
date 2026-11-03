// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import {GameTest} from "./helpers/GameTest.sol";
import {ArmyWorld} from "./helpers/ArmyWorld.sol";
import {Army} from "../src/Army.sol";
import {GameTypes as G} from "../src/libraries/GameTypes.sol";

contract CombatMathTest is GameTest {
    ArmyWorld internal world;

    function setUp() public override {
        GameTest.setUp();
        world = new ArmyWorld(army);
        world.configure(alice, G.Context(true, 0, 10, 10, 10, 10, 5, 4_000_000, 0));
        world.configure(bob, G.Context(true, 1, 10, 10, 10, 10, 5, 4_000_000, 0));
    }

    function _prepare(uint32 attackers, uint32 defenders) private returns (uint256) {
        world.train(alice, 0, attackers);
        world.train(bob, 0, defenders);
        uint256 at = army.training(address(world), alice).readyAt;
        uint256 bt = army.training(address(world), bob).readyAt;
        vm.warp(at > bt ? at : bt);
        army.completeTraining(address(world), alice);
        army.completeTraining(address(world), bob);
        uint32[7] memory units;
        units[0] = attackers;
        return world.send(alice, bob, units, false);
    }

    function testFuzzBattleLossesMatchIndependentIntegerReference(uint32 attackers, uint32 defenders) public {
        attackers = uint32(bound(attackers, 1, 1_000_000));
        defenders = uint32(bound(defenders, 1, 1_000_000));
        uint256 id = _prepare(attackers, defenders);
        vm.warp(army.movement(address(world), id).arriveAt);
        army.resolve(address(world), id);
        uint256 attackPower = uint256(attackers) * 48;
        uint256 defensePower = (uint256(defenders) * 42 + 50) * 140 / 100 + 400;
        bool decisive = attackPower >= 2 * defensePower;
        uint256 deadAttack = (uint256(attackers) * defensePower + 2 * attackPower - 1) / (2 * attackPower);
        if (deadAttack > attackers) deadAttack = attackers;
        deadAttack -= deadAttack / 10; // Field Medicine
        uint256 deadDefense = decisive
            ? defenders
            : (uint256(defenders) * attackPower + 2 * defensePower - 1) / (2 * defensePower);
        if (deadDefense > defenders) deadDefense = defenders;
        if (!decisive) deadDefense -= deadDefense / 10;
        Army.Report memory r = army.report(address(world), id);
        assertEq(r.attack, attackPower);
        assertEq(r.defense, defensePower);
        assertEq(r.decisive, decisive);
        assertEq(r.attackerLostValue, deadAttack * 180);
        assertEq(r.defenderLostValue, deadDefense * 180);
        assertEq(army.movement(address(world), id).units[0], attackers - deadAttack);
        assertEq(army.home(address(world), bob)[0], defenders - deadDefense);
        assertEq(army.allocatedRoom(address(world), alice), attackers - deadAttack);
        assertEq(army.allocatedRoom(address(world), bob), defenders - deadDefense);
        vm.warp(army.movement(address(world), id).arriveAt);
        army.resolve(address(world), id);
        assertEq(army.home(address(world), alice)[0], attackers - deadAttack);
    }

    function testReentrancyDuringBattleCannotResolveTwice() public {
        uint256 id = _prepare(100, 10);
        world.setReentry(id);
        vm.warp(army.movement(address(world), id).arriveAt);
        army.resolve(address(world), id);
        assertFalse(world.reentered());
        assertEq(army.movement(address(world), id).mode, 4);
    }

    function testBattleReReadsNFTAfterTransferWhileChampionTravels() public {
        world.creditXP(alice, 10000);
        world.allocate(alice, 0, 20, 0, 0);
        world.train(alice, 0, 100);
        world.train(bob, 0, 10);
        vm.warp(army.training(address(world), alice).readyAt);
        army.completeTraining(address(world), alice);
        army.completeTraining(address(world), bob);
        nft.setBalance(alice, 1);
        uint32[7] memory units;
        units[0] = 100;
        uint256 id = world.send(alice, bob, units, true);
        nft.move(alice, carol);
        vm.warp(army.movement(address(world), id).arriveAt);
        army.resolve(address(world), id);
        assertEq(army.report(address(world), id).attack, 4800 * 110 / 100 + 50);
    }

    function testScoutOnlyRaidHasZeroAttackNoDivisionByZero() public {
        world.train(alice, 6, 100);
        vm.warp(army.training(address(world), alice).readyAt);
        army.completeTraining(address(world), alice);
        uint32[7] memory units;
        units[6] = 100;
        uint256 id = world.send(alice, bob, units, false);
        vm.warp(army.movement(address(world), id).arriveAt);
        army.resolve(address(world), id);
        assertEq(army.report(address(world), id).attack, 0);
        assertEq(army.movement(address(world), id).units[6], 10); // medicine returns 10%
        assertEq(_sum(army.movement(address(world), id).loot), 0);
    }

    function testRaidingEmptyCampCannotPostponeRegrowth() public {
        uint16 destination = game.campTile(0);
        world.configure(alice, G.Context(true, destination + 1, 10, 10, 10, 10, 5, 4_000_000, 0));
        world.train(alice, 0, 100);
        vm.warp(army.training(address(world), alice).readyAt);
        army.completeTraining(address(world), alice);
        uint32[7] memory units;
        units[0] = 50;
        uint256 first = world.send(alice, address(0), units, false);
        vm.warp(army.movement(address(world), first).arriveAt);
        army.resolve(address(world), first);
        assertEq(army.camp(address(world), 0).defense, 0);
        uint64 regrow = army.camp(address(world), 0).regrowAt;
        uint256 second = world.send(alice, address(0), units, false);
        vm.warp(army.movement(address(world), second).arriveAt);
        army.resolve(address(world), second);
        assertEq(army.camp(address(world), 0).regrowAt, regrow);
        assertEq(army.report(address(world), second).defenderLostValue, 0);
    }

    function testCampDayChangesAtFourUTC() public {
        (uint256 defense, uint256 rate) = army.campParameters(1);
        assertEq(defense, 150);
        assertEq(rate, 20 * U);
        vm.warp((ledger.currentDay() + 1) * 1 days + 4 hours - 1);
        (defense, rate) = army.campParameters(1);
        assertEq(defense, 150);
        assertEq(rate, 20 * U);
        vm.warp(vm.getBlockTimestamp() + 1);
        (defense, rate) = army.campParameters(1);
        assertEq(defense, 190);
        assertEq(rate, 22 * U);
    }

    function testCampProductionUsesBothRatesAcrossFourUTC() public {
        uint16 destination = game.campTile(0);
        world.configure(alice, G.Context(true, destination + 1, 10, 10, 10, 10, 5, 4_000_000, 0));
        world.train(alice, 0, 100);
        vm.warp(army.training(address(world), alice).readyAt);
        army.completeTraining(address(world), alice);
        uint32[7] memory units;
        units[0] = 50;
        uint256 first = world.send(alice, address(0), units, false);
        uint256 boundary = (ledger.currentDay() + 1) * 1 days + 4 hours;
        vm.warp(boundary - 30 minutes);
        army.resolve(address(world), first);
        assertEq(army.camp(address(world), 0).stock[0], 0);
        uint256 second = world.send(alice, address(0), units, false);
        vm.warp(boundary + 30 minutes);
        army.resolve(address(world), second);
        // Size .6: half an hour at 12/h plus half an hour at 13.2/h = 12.6 each.
        for (uint8 i; i < 4; ++i) {
            assertEq(army.report(address(world), second).loot[i], 126 * U / 10);
        }
    }
}
