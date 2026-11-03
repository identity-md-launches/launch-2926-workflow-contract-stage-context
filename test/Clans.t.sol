// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import {EndgameTest} from "./helpers/EndgameTest.sol";
import {GameTypes as G} from "../src/libraries/GameTypes.sol";
import {Army} from "../src/Army.sol";
import {Clans} from "../src/Clans.sol";

contract ClansTest is EndgameTest {
    function _clanSetup() internal returns (uint256 id) {
        _advanceTo(alice, 4);
        _clanHall(alice, 3);
        _barracks(alice);
        _advanceTo(bob, 4);
        _clanHall(bob, 1);
        _barracks(bob);
        vm.prank(alice);
        id = game.foundClan("Hamsters");
        vm.prank(bob);
        game.joinClan(id);
        vm.warp(vm.getBlockTimestamp() + 8 days);
    }

    function testFoundJoinLeaveGatesAndUniqueNames() public {
        vm.expectRevert("Clan Hall 3 required");
        vm.prank(alice);
        game.foundClan("Hamsters");
        uint256 id = _clanSetup();
        assertEq(clans.clanOf(address(game), alice), id);
        assertEq(clans.clan(address(game), id).capacity, 9);
        assertTrue(clans.sameClan(address(game), alice, bob));
        vm.expectRevert("Founder leaves last");
        vm.prank(alice);
        game.leaveClan();
        vm.prank(bob);
        game.leaveClan();
        assertFalse(clans.sameClan(address(game), alice, bob));
        vm.prank(alice);
        game.leaveClan();
        vm.expectRevert("Clan name taken");
        vm.prank(alice);
        game.foundClan("hAMSTERS");
    }

    function testNoAttackInsideClanSupportOnlyAndRecallNoResourcesTransferred() public {
        _clanSetup();
        _troops(alice, 0, 10);
        uint256 aliceSeed = game.seedBalance(alice);
        uint256 bobSeed = game.seedBalance(bob);
        vm.expectRevert("Target protected");
        _send(alice, bob, 0, 0, 1, false, 1);
        vm.expectRevert("Invalid support");
        _send(alice, bob, 0, 0, 1, true, 3);
        uint256 id = _send(alice, bob, 0, 0, 6, false, 3);
        _arrive(id);
        assertEq(army.movement(address(game), id).mode, 5);
        assertEq(army.supportMovements(address(game), bob).length, 1);
        assertEq(army.home(address(game), alice)[0], 4);
        assertEq(army.home(address(game), bob)[0], 0);
        assertEq(game.seedBalance(alice), aliceSeed);
        assertEq(game.seedBalance(bob), bobSeed);
        vm.prank(bob);
        game.recall(id);
        _arrive(id);
        assertEq(army.home(address(game), alice)[0], 10);
        assertEq(army.supportMovements(address(game), bob).length, 0);
        assertEq(_sum(army.movement(address(game), id).loot), 0);
    }

    function testFormerClanSupportCanBeReturnedByAnyone() public {
        _clanSetup();
        _troops(alice, 0, 4);
        uint256 id = _send(alice, bob, 0, 0, 4, false, 3);
        _arrive(id);
        vm.expectRevert("Support still allied");
        army.returnFormerSupport(address(game), id);
        vm.prank(bob);
        game.leaveClan();
        vm.prank(outsider);
        army.returnFormerSupport(address(game), id);
        _arrive(id);
        assertEq(army.home(address(game), alice)[0], 4);
    }

    function testJoiningClanInFlightCancelsAttack() public {
        _clanSetup();
        _troops(alice, 0, 8);
        uint256 clanId = clans.clanOf(address(game), alice);
        vm.prank(bob);
        game.leaveClan();
        uint256 id = _send(alice, bob, 0, 0, 8, true, 1);
        vm.prank(bob);
        game.joinClan(clanId);
        _arrive(id);
        assertTrue(army.report(address(game), id).cancelled);
        _arrive(id);
        assertEq(army.home(address(game), alice)[0], 8);
    }

    function testSupportDefendsAndLossesReleaseOriginsRoom() public {
        _clanSetup();
        _troops(alice, 0, 10);
        _troops(bob, 0, 5);
        uint256 support = _send(alice, bob, 0, 0, 10, false, 3);
        _arrive(support);
        _found(carol, "Carol");
        _advanceTo(carol, 4);
        _barracks(carol);
        _burrow(carol, 4);
        _troops(carol, 0, 100);
        uint256 id = _send(carol, bob, 0, 0, 100, true, 1);
        _arrive(id);
        Army.Report memory r = army.report(address(game), id);
        assertTrue(r.decisive);
        assertEq(r.defenderLostValue, 15 * 180);
        assertEq(army.allocatedRoom(address(game), alice), 0);
        assertEq(army.allocatedRoom(address(game), bob), 0);
        assertEq(army.movement(address(game), support).units[0], 0);
    }

    function testClanCapacityAndFounderUpgrade() public {
        // Test the module's bounded membership independently in this test's namespace.
        uint256 id = clans.found(alice, "Capacity", 3);
        for (uint256 i; i < 8; ++i) {
            clans.join(address(uint160(2000 + i)), id, 1);
        }
        vm.expectRevert("Clan full or missing");
        clans.join(carol, id, 1);
        vm.expectRevert("Cannot raise capacity");
        clans.raiseCapacity(bob, 4);
        clans.raiseCapacity(alice, 4);
        clans.join(carol, id, 1);
        assertEq(clans.clan(address(this), id).members.length, 10);
    }

    function testRankingFormulaWeekIsolationAndCanonicalNamespace() public {
        clans.record(alice, 0, 10000 * U);
        clans.record(alice, 1, 2000 * U);
        clans.record(alice, 2, 5000);
        clans.record(alice, 3, 5000);
        assertEq(clans.overall(address(this), alice, false, 0), 170);
        assertEq(clans.overall(address(game), alice, false, 0), 0);
        uint256 w = clans.week();
        assertEq(clans.overall(address(this), alice, true, w), 170);
        vm.warp(vm.getBlockTimestamp() + 7 days);
        clans.record(alice, 0, 100 * U);
        clans.record(alice, 2, 50000);
        assertEq(clans.overall(address(this), alice, true, w), 170);
        assertEq(clans.overall(address(this), alice, true, w + 1), 2);
        assertEq(clans.overall(address(this), alice, false, 0), 222);
    }
}
