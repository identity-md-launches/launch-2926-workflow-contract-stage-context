// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import {GameTest} from "./helpers/GameTest.sol";
import {GameTypes as G} from "../src/libraries/GameTypes.sol";

contract RulesTest is GameTest {
    function testExactStartingQuotesAndCapacities() public view {
        (uint256[4] memory c, uint256 seconds_) = rules.fieldQuote(0, 2);
        assertEq(c[0], 48 * U);
        assertEq(c[1], 80 * U);
        assertEq(seconds_, 2016);
        uint256 seed;
        (c, seed, seconds_) = rules.buildingQuote(G.TH, 2);
        assertEq(c[0], 315 * U);
        assertEq(c[1], 2975 * U / 10);
        assertEq(seed, 10005 * U / 10);
        assertEq(seconds_, 4050);
        assertEq(rules.fieldRate(1), 18 * U);
        assertEq(rules.fieldRate(2), 252 * U / 10);
        assertEq(rules.capacity(0, 0), 1500 * U);
        assertEq(rules.capacity(0, 1), 3300 * U);
        assertEq(rules.capacity(1, 0), 300 * U);
        assertEq(rules.capacity(1, 1), 800 * U);
        assertEq(rules.capacity(2, 0), 30);
        assertEq(rules.capacity(2, 1), 50);
    }

    function testResearchCostsAndGates() public view {
        (uint256[4] memory c, uint256 seed, uint256 duration, uint8 academy) = rules.researchQuote(5);
        assertEq(c[0], 351384 * U / 100);
        assertEq(seed, 4800 * U);
        assertEq(duration, 75582);
        assertEq(academy, 8);
    }

    function testUnitStatsAndRoomCosts() public view {
        (uint256 a, uint256 d, uint256 speed, uint256 carry, uint256 room, uint256 time_) = rules.unitStats(4);
        assertEq(a, 90);
        assertEq(d, 50);
        assertEq(speed, 14);
        assertEq(carry, 80);
        assertEq(room, 2);
        assertEq(time_, 2100);
        (uint256[4] memory c, uint256 duration, uint256 rooms) = rules.unitQuote(5, 1, 4, 100);
        assertEq(c[0], 32000 * U);
        assertEq(duration, 420000);
        assertEq(rooms, 400);
    }

    function testMaximumLevelsAndArmiesHaveBoundedArithmetic() public view {
        for (uint8 kind; kind < 11; ++kind) {
            (uint256[4] memory costs, uint256 seed, uint256 time_) =
                rules.buildingQuote(kind, kind == G.STORE || kind == G.VAULT ? 20 : 10);
            assertLt(_sum(costs) + seed, 1e13);
            assertLt(time_, 1e8);
        }
        for (uint8 kind; kind < 7; ++kind) {
            (uint256[4] memory costs, uint256 time_, uint256 room) = rules.unitQuote(kind, 10, 5, 1_000_000);
            assertLt(_sum(costs), 1e16);
            assertLt(time_, 1e10);
            assertLe(room, 4_000_000);
        }
        assertLt(rules.capacity(0, 20), 1e13);
        assertLt(rules.capacity(1, 20), 1e13);
        assertLt(rules.capacity(2, 10), 1e6);
    }

    function testFuzzNFTSpeedReductionNeverExceedsThirtyPercent(uint256 n, uint64 work, uint32 base, uint8 th)
        public
        view
    {
        th = uint8(bound(th, 1, 10));
        base = uint32(bound(base, 1, 10_000_000));
        uint256 duration = rules.buildDuration(base, th, n, work);
        uint256 without = G.ceilDiv(uint256(base) * (100 - 3 * (th - 1)), 100);
        assertLe(duration, without);
        assertGe(duration, G.ceilDiv(uint256(base) * (100 - 3 * (th - 1)) * 70, 10000));
    }

    function testFuzzCapsMonotonic(uint8 level) public view {
        level = uint8(bound(level, 1, 20));
        assertGt(rules.capacity(0, level), rules.capacity(0, level - 1));
        assertGt(rules.capacity(1, level), rules.capacity(1, level - 1));
    }

    function testShuffleIsPermutationAndCampSeparation() public view {
        bool[10000] memory seen;
        for (uint256 i; i < 10000; ++i) {
            uint16 tile = game.tileForSlot(i);
            assertFalse(seen[tile]);
            seen[tile] = true;
        }
        for (uint256 i; i < 200; ++i) {
            assertEq(game.campTile(i), game.tileForSlot(i * 50 + 49));
        }
    }

    function testInvalidArgumentsFail() public {
        vm.expectRevert();
        rules.fieldQuote(8, 1);
        vm.expectRevert();
        rules.buildingQuote(11, 1);
        vm.expectRevert();
        rules.buildingQuote(0, 11);
        vm.expectRevert();
        rules.capacity(2, 11);
        vm.expectRevert();
        rules.researchQuote(6);
        vm.expectRevert();
        rules.unitQuote(4, 1, 2, 1);
        vm.expectRevert();
        rules.unitQuote(0, 0, 0, 1);
        vm.expectRevert();
        rules.unitQuote(0, 1, 0, 0);
        vm.expectRevert();
        rules.grow(1, 1, 1, 21);
    }

    function testDistancesAndForcedSpeedBounds() public view {
        assertEq(army.travelTime(0, 1, 6), 600);
        assertEq(army.travelTime(0, 100, 6), 600);
        assertGt(army.travelTime(0, 101, 6), 600);
        assertEq(army.travelTime(0, 0, 6), 600);
        assertLt(army.travelTime(0, 9999, 3), 47 hours);
    }
}
