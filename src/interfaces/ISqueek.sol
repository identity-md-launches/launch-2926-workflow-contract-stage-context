// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @notice Read-only SqueekCore ABI. cumulativeWork is the SECOND ABI word.
interface ISqueekCore {
    struct CoreState {
        uint64 settledThroughRound;
        uint64 cumulativeWork;
        uint96 cumulativeBlockUnits;
        uint64 blockHeight;
        uint96 blockProgress;
        uint32 workPerThousandBlocks;
        uint256 authorizationNonce;
        bool paused;
    }
    function state() external view returns (CoreState memory);
}

interface ISqueekNFT {
    function balanceOf(address account) external view returns (uint256);
}
