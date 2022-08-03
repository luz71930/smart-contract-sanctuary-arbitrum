// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

interface IRodeo {
    function lastGain() external view returns (uint256);
    function supplyIndex() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function borrowIndex() external view returns (uint256);
    function totalBorrow() external view returns (uint256);
    function getUtilization() external view returns (uint256);
    function getSupplyRate(uint256) external view returns (uint256);
    function getBorrowRate(uint256) external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function life(uint) external view returns (uint256);
    function positions(uint256)
        external
        view
        returns (address, address, uint256, uint256, uint256);
}

interface IStrategy {
    function name() external view returns (string memory);
    function rate(uint256) external view returns (uint256);
}

contract RodeoPeek {
    uint256 private constant ONE_YEAR = 31536000;
    IRodeo public immutable r;

    constructor(address rodeo) {
        r = IRodeo(rodeo);
    }

    function peek()
        external
        view
        returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256)
    {
        (uint256 borrowIndex, uint256 supplyIndex) = indexes();
        uint256 totalSupply = r.totalSupply() * supplyIndex / 1e18;
        uint256 totalBorrow = r.totalBorrow() * borrowIndex / 1e18;
        uint256 utilization = 0;
        if (totalSupply > 0) {
            utilization = totalBorrow * 1e18 / totalSupply;
        }
        uint256 supplyRate = r.getSupplyRate(utilization) * ONE_YEAR;
        uint256 borrowRate = r.getBorrowRate(utilization) * ONE_YEAR;
        return (
            utilization,
            supplyIndex,
            borrowIndex,
            supplyRate,
            borrowRate,
            totalSupply,
            totalBorrow
        );
    }

    function peekPosition(uint256 id)
        external
        view
        returns (string memory, uint256, uint256, uint256, uint256, uint256, uint256)
    {
        (uint256 borrowIndex,) = indexes();
        (, address strategy, uint256 ini, uint256 sha, uint256 bor) =
            r.positions(id);
        uint health = r.life(id);
        return (
            IStrategy(strategy).name(),
            ini,
            sha,
            IStrategy(strategy).rate(sha),
            bor * borrowIndex / 1e18,
            r.getBorrowRate(r.getUtilization()) * ONE_YEAR,
            health
        );
    }

    function indexes() internal view returns (uint256, uint256) {
        uint256 borrowIndex = r.borrowIndex();
        uint256 supplyIndex = r.supplyIndex();
        uint256 utilization = r.getUtilization();
        uint256 time = block.timestamp - r.lastGain();
        borrowIndex +=
            (borrowIndex * r.getBorrowRate(utilization) * time) / 1e18;
        supplyIndex +=
            (supplyIndex * r.getSupplyRate(utilization) * time) / 1e18;
        return (borrowIndex, supplyIndex);
    }
}