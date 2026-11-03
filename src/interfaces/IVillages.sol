// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import {GameTypes as G} from "../libraries/GameTypes.sol";

interface IVillages {
    function armyContext(address player) external view returns (G.Context memory);
    function armySpend(address player, uint256[4] calldata cost) external;
    function armyTouch(address player) external;
    function armyLoot(address player, uint256 capacity) external returns (uint256[4] memory);
    function armyCredit(address player, uint256[4] calldata amounts) external;
    function armyDamageWalls(address player, uint8 damage) external;
    function armyRecord(address player, uint8 kind, uint256 amount) external;
}
