// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import {ISqueekCore, ISqueekNFT} from "../../src/interfaces/ISqueek.sol";

contract MockCore is ISqueekCore {
    uint64 public work = 100_000;
    bool public broken;

    function setWork(uint64 value) external {
        work = value;
    }

    function setBroken(bool value) external {
        broken = value;
    }

    function state() external view returns (CoreState memory s) {
        require(!broken, "Core offline");
        s.settledThroughRound = 777;
        s.cumulativeWork = work;
        s.cumulativeBlockUnits = 999999999999;
        s.blockHeight = 999;
        s.blockProgress = 123;
        s.workPerThousandBlocks = 4321;
        s.authorizationNonce = 42;
    }
}

contract MockNFT is ISqueekNFT {
    mapping(address => uint256) public balances;
    bool public broken;

    function setBalance(address who, uint256 value) external {
        balances[who] = value;
    }

    function setBroken(bool value) external {
        broken = value;
    }

    function move(address from, address to) external {
        require(balances[from] != 0);
        --balances[from];
        ++balances[to];
    }

    function balanceOf(address who) external view returns (uint256) {
        require(!broken, "NFT offline");
        return balances[who];
    }
}

contract ReenteringCore {
    address public target;

    function setTarget(address target_) external {
        target = target_;
    }

    function state() external returns (ISqueekCore.CoreState memory s) {
        (bool ok,) = target.call(abi.encodeWithSignature("checkpoint()"));
        require(!ok, "Reentry succeeded");
        s.cumulativeWork = 100_000;
    }
}

contract ReenteringNFT {
    address public target;

    function setTarget(address target_) external {
        target = target_;
    }

    function balanceOf(address) external returns (uint256) {
        (bool ok,) = target.call(abi.encodeWithSignature("treasury(uint8,uint8)", uint8(2), uint8(0)));
        require(!ok, "Reentry succeeded");
        return 1;
    }
}

contract ShortCore {
    function state() external pure returns (uint256) {
        return 123;
    }
}

contract InvalidWidthCore {
    function state() external pure returns (uint256[8] memory words) {
        words[1] = uint256(type(uint64).max) + 1;
    }
}

contract LongNFT {
    function balanceOf(address) external pure returns (uint256, uint256) {
        return (1, 2);
    }
}
