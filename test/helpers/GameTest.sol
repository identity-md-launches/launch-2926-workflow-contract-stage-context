// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import {Test} from "forge-std/Test.sol";
import {GameTypes as G} from "../../src/libraries/GameTypes.sol";
import {GameRules} from "../../src/GameRules.sol";
import {SeedLedger} from "../../src/SeedLedger.sol";
import {Clans} from "../../src/Clans.sol";
import {Army} from "../../src/Army.sol";
import {Villages} from "../../src/Villages.sol";
import {MockCore, MockNFT} from "./Mocks.sol";

abstract contract GameTest is Test {
    uint256 internal constant U = 1_000_000;
    uint256 internal constant START = 1_800_000_000;
    address internal owner = address(0x1234);
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal carol = address(0xCA201);
    address internal outsider = address(0xBAD);
    GameRules internal rules;
    SeedLedger internal ledger;
    Clans internal clans;
    Army internal army;
    Villages internal game;
    MockCore internal core;
    MockNFT internal nft;

    function setUp() public virtual {
        vm.warp(START);
        rules = new GameRules();
        core = new MockCore();
        nft = new MockNFT();
        ledger = new SeedLedger(owner, address(core), address(nft));
        clans = new Clans();
        army = new Army(rules, ledger, clans);
        game = new Villages(rules, ledger, clans, army);
        _found(alice, "Alice");
        _found(bob, "Bob");
    }

    function _found(address who, string memory name) internal {
        vm.prank(who);
        game.found(name);
    }

    function _checkpoint(uint64 delta) internal {
        vm.warp((ledger.currentDay() + 1) * 1 days + 4 hours);
        core.setWork(core.work() + delta);
        ledger.checkpoint();
    }

    function _build(address who, uint8 target) internal {
        vm.prank(who);
        game.orderBuild(target, 0);
        Villages.BuildOrder memory b = game.buildOrder(who, 0);
        vm.warp(b.readyAt);
        game.completeBuild(who, 0);
    }

    function _train(address who, uint8 kind, uint32 count) internal {
        vm.prank(who);
        game.train(kind, count);
        Army.Training memory t = army.training(address(game), who);
        vm.warp(t.readyAt);
        army.completeTraining(address(game), who);
    }

    function _arrive(uint256 id) internal {
        Army.Movement memory m = army.movement(address(game), id);
        vm.warp(m.arriveAt);
        army.resolve(address(game), id);
    }

    function _send(address who, address target, uint16 camp, uint8 kind, uint32 count, bool champ, uint8 mode)
        internal
        returns (uint256)
    {
        uint32[7] memory units;
        units[kind] = count;
        vm.prank(who);
        return game.send(target, camp, units, champ, mode);
    }

    function _sum(uint256[4] memory values) internal pure returns (uint256) {
        return values[0] + values[1] + values[2] + values[3];
    }
}
