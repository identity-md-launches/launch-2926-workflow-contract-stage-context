// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import {Army} from "../../src/Army.sol";
import {GameTypes as G} from "../../src/libraries/GameTypes.sol";
import {IVillages} from "../../src/interfaces/IVillages.sol";

/// @dev Test-only isolated world with generous resources for independent combat arithmetic checks.
contract ArmyWorld is IVillages {
    Army public immutable army;
    mapping(address => G.Context) private contexts;
    mapping(address => mapping(uint8 => uint256)) public points;
    bool public attemptReentry;
    bool public reentered;
    uint256 public resolving;

    constructor(Army army_) {
        army = army_;
    }

    function configure(address who, G.Context calldata context) external {
        contexts[who] = context;
    }

    function setReentry(uint256 id) external {
        attemptReentry = true;
        resolving = id;
    }

    function train(address who, uint8 kind, uint32 count) external {
        army.train(who, kind, count);
    }

    function send(address who, address target, uint32[7] calldata units, bool champion)
        external
        returns (uint256)
    {
        return army.send(who, target, 0, units, champion, 1);
    }

    function creditXP(address who, uint256 amount) external {
        army.creditXP(who, amount);
    }

    function allocate(address who, uint8 m, uint8 a, uint8 d, uint8 c) external {
        army.allocate(who, m, a, d, c);
    }

    function armyContext(address who) external view returns (G.Context memory) {
        return contexts[who];
    }
    function armySpend(address, uint256[4] calldata) external {}

    function armyTouch(address) external {
        if (attemptReentry) {
            (bool success,) = address(army).call(abi.encodeCall(Army.resolve, (address(this), resolving)));
            reentered = success;
        }
    }

    function armyLoot(address, uint256) external pure returns (uint256[4] memory amounts) {
        return amounts;
    }
    function armyCredit(address, uint256[4] calldata) external {}
    function armyDamageWalls(address, uint8) external {}

    function armyRecord(address who, uint8 kind, uint256 amount) external {
        points[who][kind] += amount;
    }
}
