// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {GameTest} from "./helpers/GameTest.sol";
import {MockCore} from "./helpers/Mocks.sol";
import {Villages} from "../src/Villages.sol";
import {Army} from "../src/Army.sol";
import {SeedLedger} from "../src/SeedLedger.sol";
import {GameTypes as G} from "../src/libraries/GameTypes.sol";

contract GameHandler is Test {
    Villages public game;
    Army public army;
    SeedLedger public ledger;
    MockCore public core;
    address[2] public players;
    bool public isolationBroken;
    uint256 public successfulActions;
    uint256 public resolvedMovements;

    constructor(Villages game_, Army army_, SeedLedger ledger_, MockCore core_, address a, address b) {
        game = game_;
        army = army_;
        ledger = ledger_;
        core = core_;
        players = [a, b];
    }

    function _other(uint8 actor) private view returns (bytes32) {
        address who = players[1 - actor];
        return keccak256(abi.encode(game.stock(who), game.seedBalance(who)));
    }

    function _check(uint8 actor, bytes32 old) private {
        if (_other(actor) != old) isolationBroken = true;
    }

    function advance(uint32 elapsed, uint32 work) external {
        vm.warp(vm.getBlockTimestamp() + bound(elapsed, 1, 2 days));
        core.setWork(core.work() + uint64(bound(work, 0, 30000)));
        try ledger.checkpoint() {
            ++successfulActions;
        } catch {}
    }

    function claim(uint8 actor) external {
        actor %= 2;
        bytes32 before_ = _other(actor);
        vm.prank(players[actor]);
        try game.claimSeed() {
            ++successfulActions;
        } catch {}
        _check(actor, before_);
    }

    function build(uint8 actor, uint8 target, uint8 slot) external {
        actor %= 2;
        bytes32 before_ = _other(actor);
        vm.prank(players[actor]);
        try game.orderBuild(target % 19, slot % 2) {
            ++successfulActions;
        } catch {}
        _check(actor, before_);
    }

    function finish(uint8 actor, uint8 slot, bool cancel) external {
        actor %= 2;
        bytes32 before_ = _other(actor);
        if (cancel) {
            vm.prank(players[actor]);
            try game.cancelBuild(slot % 2) {
                ++successfulActions;
            } catch {}
        } else {
            try game.completeBuild(players[actor], slot % 2) {
                ++successfulActions;
            } catch {}
        }
        _check(actor, before_);
    }

    function market(uint8 actor, uint8 input, uint8 output, uint8 lots) external {
        actor %= 2;
        bytes32 before_ = _other(actor);
        vm.prank(players[actor]);
        try game.exchange(input % 5, output % 4, bound(lots, 1, 10)) {
            ++successfulActions;
        } catch {}
        _check(actor, before_);
    }

    function treasury(uint8 actor, uint8 kind, uint8 resource) external {
        actor %= 2;
        bytes32 before_ = _other(actor);
        vm.prank(players[actor]);
        try game.treasury(kind % 3, resource % 4) {
            ++successfulActions;
        } catch {}
        _check(actor, before_);
    }

    function train(uint8 actor, uint8 kind, uint8 count) external {
        actor %= 2;
        bytes32 before_ = _other(actor);
        vm.prank(players[actor]);
        try game.train(kind % 7, uint32(bound(count, 1, 5))) {
            ++successfulActions;
        } catch {}
        _check(actor, before_);
    }

    function completeTraining(uint8 actor) external {
        actor %= 2;
        try army.completeTraining(address(game), players[actor]) {
            ++successfulActions;
        } catch {}
    }

    function raidCamp(uint8 actor, uint8 campId, uint8 count, bool champion) external {
        actor %= 2;
        bytes32 before_ = _other(actor);
        uint32[7] memory units;
        units[0] = uint32(bound(count, 1, 5));
        vm.prank(players[actor]);
        try game.send(address(0), campId % 200, units, champion, 1) returns (uint256) {
            ++successfulActions;
        } catch {}
        _check(actor, before_);
    }

    function resolve(uint256 id) external {
        uint256 count = army.movementCount(address(game));
        if (count == 0) return;
        id = bound(id, 1, count);
        try army.resolve(address(game), id) {
            ++successfulActions;
            ++resolvedMovements;
        } catch {}
    }

    function sync(uint8 actor) external {
        actor %= 2;
        bytes32 before_ = _other(actor);
        game.sync(players[actor]);
        _check(actor, before_);
    }

    function research(uint8 actor, bool complete) external {
        actor %= 2;
        bytes32 before_ = _other(actor);
        if (complete) {
            try game.completeResearch(players[actor]) {
                ++successfulActions;
            } catch {}
        } else {
            vm.prank(players[actor]);
            try game.orderResearch() {
                ++successfulActions;
            } catch {}
        }
        _check(actor, before_);
    }
}

contract GameInvariantTest is StdInvariant, GameTest {
    GameHandler internal handler;

    function setUp() public override {
        GameTest.setUp();
        // Initial villages reached through ordinary gameplay; all subsequent mutations use public player APIs.
        _build(alice, 8 + G.TH);
        _build(bob, 8 + G.TH);
        _build(alice, 8 + G.BARRACKS);
        _build(bob, 8 + G.BARRACKS);
        vm.warp(vm.getBlockTimestamp() + 2 days);
        _build(alice, 8 + G.MARKET);
        _build(bob, 8 + G.MARKET);
        _train(alice, 0, 3);
        _train(bob, 0, 3);
        handler = new GameHandler(game, army, ledger, core, alice, bob);
        targetContract(address(handler));
        bytes4[] memory selectors = new bytes4[](12);
        selectors[0] = handler.advance.selector;
        selectors[1] = handler.claim.selector;
        selectors[2] = handler.build.selector;
        selectors[3] = handler.finish.selector;
        selectors[4] = handler.market.selector;
        selectors[5] = handler.treasury.selector;
        selectors[6] = handler.train.selector;
        selectors[7] = handler.completeTraining.selector;
        selectors[8] = handler.raidCamp.selector;
        selectors[9] = handler.resolve.selector;
        selectors[10] = handler.sync.selector;
        selectors[11] = handler.research.selector;
        targetSelector(FuzzSelector(address(handler), selectors));
    }

    function invariant_seedConservationAndNoCanonicalTransfers() public view {
        assertEq(
            game.seedBalance(alice) + game.seedBalance(bob),
            ledger.minted(address(game)) - ledger.burned(address(game))
        );
        assertFalse(handler.isolationBroken());
    }

    function invariant_storageNeverExceeded() public view {
        for (uint256 i; i < 2; ++i) {
            address who = i == 0 ? alice : bob;
            uint256[4] memory values = game.stock(who);
            for (uint256 j; j < 4; ++j) {
                assertLe(values[j], game.storageCapacity(who));
            }
        }
    }

    function invariant_allCommittedTroopsExactlyAccountedFor() public view {
        for (uint256 p; p < 2; ++p) {
            address who = p == 0 ? alice : bob;
            uint256 room;
            uint32[7] memory atHome = army.home(address(game), who);
            for (uint8 i; i < 7; ++i) {
                (,,,, uint256 r,) = rules.unitStats(i);
                room += atHome[i] * r;
            }
            Army.Training memory t = army.training(address(game), who);
            if (t.readyAt != 0) {
                (,,,, uint256 r,) = rules.unitStats(t.kind);
                room += t.count * r;
            }
            uint256 count = army.movementCount(address(game));
            for (uint256 id = 1; id <= count; ++id) {
                Army.Movement memory m = army.movement(address(game), id);
                if (m.owner == who && m.mode != 6) {
                    for (uint8 i; i < 7; ++i) {
                        (,,,, uint256 r,) = rules.unitStats(i);
                        room += m.units[i] * r;
                    }
                }
            }
            assertEq(army.allocatedRoom(address(game), who), room);
            assertLe(room, game.roomCapacity(who));
        }
    }

    function invariant_oneVillagePerWalletAndDistinctTiles() public view {
        assertEq(game.villageCount(), 2);
        assertTrue(game.village(alice).tile != game.village(bob).tile);
        assertEq(game.tileOwner(game.village(alice).tile), alice);
        assertEq(game.tileOwner(game.village(bob).tile), bob);
    }

    function invariant_checkpointDaysStrictlyIncreaseAndNoETHCustody() public view {
        uint256 count = ledger.observationCount();
        for (uint256 i = 1; i < count; ++i) {
            assertGt(ledger.observation(i).day, ledger.observation(i - 1).day);
        }
        assertEq(
            address(game).balance + address(army).balance + address(ledger).balance + address(clans).balance,
            0
        );
    }
}
