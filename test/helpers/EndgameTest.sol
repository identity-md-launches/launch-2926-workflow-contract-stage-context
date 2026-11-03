// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import {GameTest} from "./GameTest.sol";
import {GameTypes as G} from "../../src/libraries/GameTypes.sol";

/// @dev Resource fixture impersonates the immutable Army ONLY to set up large late-game states.
/// Production access-control tests separately reject every unprivileged accounting callback.
abstract contract EndgameTest is GameTest {
    function _fill(address who) internal {
        uint256 cap = game.storageCapacity(who);
        uint256[4] memory values = [cap, cap, cap, cap];
        vm.prank(address(army));
        game.armyCredit(who, values);
    }

    function _fundedBuild(address who, uint8 target) internal {
        _fill(who);
        _build(who, target);
    }

    function _advanceTo(address who, uint8 hall) internal {
        _checkpoint(1_000_000_000);
        vm.prank(who);
        game.claimSeed();
        _fundedBuild(who, 8 + G.STORE);
        while (game.village(who).buildings[G.TH] < hall) {
            uint8 th = game.village(who).buildings[G.TH];
            while (game.village(who).buildings[G.STORE] < th * 2) _fundedBuild(who, 8 + G.STORE);
            _fundedBuild(who, 8 + G.TH);
        }
    }

    function _research(address who, uint8 tier) internal {
        if (game.village(who).buildings[G.ACADEMY] == 0) _fundedBuild(who, 8 + G.ACADEMY);
        while (game.village(who).tier < tier) {
            uint8 next = game.village(who).tier + 1;
            (,,, uint8 required) = rules.researchQuote(next);
            while (game.village(who).buildings[G.ACADEMY] < required) _fundedBuild(who, 8 + G.ACADEMY);
            _fill(who);
            vm.prank(who);
            game.orderResearch();
            vm.warp(game.study(who).readyAt);
            game.completeResearch(who);
        }
    }

    function _barracks(address who) internal {
        if (game.village(who).buildings[G.BARRACKS] == 0) _fundedBuild(who, 8 + G.BARRACKS);
    }

    function _clanHall(address who, uint8 level) internal {
        _research(who, 2);
        while (game.village(who).buildings[G.CLAN] < level) _fundedBuild(who, 8 + G.CLAN);
    }

    function _troops(address who, uint8 kind, uint32 count) internal {
        _fill(who);
        _train(who, kind, count);
    }

    function _burrow(address who, uint8 level) internal {
        while (game.village(who).buildings[G.BURROW] < level) _fundedBuild(who, 8 + G.BURROW);
    }
}
