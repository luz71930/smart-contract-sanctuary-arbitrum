pragma solidity ^0.8.0;

import "./interfaces/IPairFactory.sol";
import "./interfaces/IAmmFactory.sol";
import "./interfaces/IMarginFactory.sol";
import "./interfaces/IAmm.sol";
import "./interfaces/IMargin.sol";
import "../utils/Ownable.sol";

contract PairFactory is IPairFactory, Ownable {
    address public override ammFactory;
    address public override marginFactory;

    function init(address ammFactory_, address marginFactory_) external onlyAdmin {
        require(ammFactory == address(0) && marginFactory == address(0), "PairFactory: ALREADY_INITED");
        require(ammFactory_ != address(0) && marginFactory_ != address(0), "PairFactory: ZERO_ADDRESS");
        ammFactory = ammFactory_;
        marginFactory = marginFactory_;
    }

    function createPair(address baseToken, address quoteToken) external override returns (address amm, address margin) {
        amm = IAmmFactory(ammFactory).createAmm(baseToken, quoteToken);
        margin = IMarginFactory(marginFactory).createMargin(baseToken, quoteToken);
        IAmmFactory(ammFactory).initAmm(baseToken, quoteToken, margin);
        IMarginFactory(marginFactory).initMargin(baseToken, quoteToken, amm);
        emit NewPair(baseToken, quoteToken, amm, margin);
    }

    function getAmm(address baseToken, address quoteToken) external view override returns (address) {
        return IAmmFactory(ammFactory).getAmm(baseToken, quoteToken);
    }

    function getMargin(address baseToken, address quoteToken) external view override returns (address) {
        return IMarginFactory(marginFactory).getMargin(baseToken, quoteToken);
    }
}

// SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

interface IPairFactory {
    event NewPair(address indexed baseToken, address indexed quoteToken, address amm, address margin);

    function createPair(address baseToken, address quotoToken) external returns (address amm, address margin);

    function ammFactory() external view returns (address);

    function marginFactory() external view returns (address);

    function getAmm(address baseToken, address quoteToken) external view returns (address);

    function getMargin(address baseToken, address quoteToken) external view returns (address);
}

pragma solidity ^0.8.0;

interface IAmmFactory {
    event AmmCreated(address indexed baseToken, address indexed quoteToken, address amm);

    function createAmm(address baseToken, address quoteToken) external returns (address amm);

    function initAmm(
        address baseToken,
        address quoteToken,
        address margin
    ) external;

    function setFeeTo(address) external;

    function setFeeToSetter(address) external;

    function upperFactory() external view returns (address);

    function config() external view returns (address);

    function feeTo() external view returns (address);

    function feeToSetter() external view returns (address);

    function getAmm(address baseToken, address quoteToken) external view returns (address amm);
}

pragma solidity ^0.8.0;

interface IMarginFactory {
    event MarginCreated(address indexed baseToken, address indexed quoteToken, address margin);

    function createMargin(address baseToken, address quoteToken) external returns (address margin);

    function initMargin(
        address baseToken,
        address quoteToken,
        address amm
    ) external;

    function upperFactory() external view returns (address);

    function config() external view returns (address);

    function getMargin(address baseToken, address quoteToken) external view returns (address margin);
}

// SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

interface IAmm {
    event Mint(address indexed sender, address indexed to, uint256 baseAmount, uint256 quoteAmount, uint256 liquidity);
    event Burn(address indexed sender, address indexed to, uint256 baseAmount, uint256 quoteAmount, uint256 liquidity);
    event Swap(address indexed inputToken, address indexed outputToken, uint256 inputAmount, uint256 outputAmount);
    event ForceSwap(address indexed inputToken, address indexed outputToken, uint256 inputAmount, uint256 outputAmount);
    event Rebase(uint256 quoteReserveBefore, uint256 quoteReserveAfter);
    event Sync(uint112 reserveBase, uint112 reserveQuote);

    // only factory can call this function
    function initialize(
        address baseToken_,
        address quoteToken_,
        address margin_
    ) external;

    function mint(address to)
        external
        returns (
            uint256 baseAmount,
            uint256 quoteAmount,
            uint256 liquidity
        );

    function burn(address to)
        external
        returns (
            uint256 baseAmount,
            uint256 quoteAmount,
            uint256 liquidity
        );

    // only binding margin can call this function
    function swap(
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        uint256 outputAmount
    ) external returns (uint256[2] memory amounts);

    // only binding margin can call this function
    function forceSwap(
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        uint256 outputAmount
    ) external;

    function rebase() external returns (uint256 quoteReserveAfter);

    function factory() external view returns (address);

    function config() external view returns (address);

    function baseToken() external view returns (address);

    function quoteToken() external view returns (address);

    function margin() external view returns (address);

    function price0CumulativeLast() external view returns (uint256);

    function price1CumulativeLast() external view returns (uint256);

    function getReserves()
        external
        view
        returns (
            uint112 reserveBase,
            uint112 reserveQuote,
            uint32 blockTimestamp
        );

    function estimateSwap(
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        uint256 outputAmount
    ) external view returns (uint256[2] memory amounts);

    function MINIMUM_LIQUIDITY() external pure returns (uint256);
}

// SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

interface IMargin {
    event AddMargin(address indexed trader, uint256 depositAmount);
    event RemoveMargin(address indexed trader, uint256 withdrawAmount);
    event OpenPosition(address indexed trader, uint8 side, uint256 baseAmount, uint256 quoteAmount);
    event ClosePosition(
        address indexed trader,
        uint256 quoteAmount,
        uint256 baseAmount,
        uint256 quoteSize,
        bool isLong
    );
    event Liquidate(
        address indexed liquidator,
        address indexed trader,
        uint256 quoteAmount,
        uint256 baseAmount,
        uint256 bonus
    );
    event UpdateCPF(uint256 timeStamp, int256 cpf);

    /// @notice only factory can call this function
    /// @param baseToken_ margin's baseToken.
    /// @param quoteToken_ margin's quoteToken.
    /// @param amm_ amm address.
    function initialize(
        address baseToken_,
        address quoteToken_,
        address amm_
    ) external;

    /// @notice add margin to trader
    /// @param trader .
    /// @param depositAmount base amount to add.
    function addMargin(address trader, uint256 depositAmount) external;

    /// @notice remove margin to msg.sender
    /// @param withdrawAmount base amount to withdraw.
    function removeMargin(address trader, uint256 withdrawAmount) external;

    /// @notice open position with side and quoteAmount by msg.sender
    /// @param side long or short.
    /// @param quoteAmount quote amount.
    function openPosition(
        address trader,
        uint8 side,
        uint256 quoteAmount
    ) external returns (uint256 baseAmount);

    /// @notice close msg.sender's position with quoteAmount
    /// @param quoteAmount quote amount to close.
    function closePosition(address trader, uint256 quoteAmount) external returns (uint256 baseAmount);

    /// @notice liquidate trader
    function liquidate(address trader)
        external
        returns (
            uint256 quoteAmount,
            uint256 baseAmount,
            uint256 bonus
        );

    /// @notice get factory address
    function factory() external view returns (address);

    /// @notice get config address
    function config() external view returns (address);

    /// @notice get base token address
    function baseToken() external view returns (address);

    /// @notice get quote token address
    function quoteToken() external view returns (address);

    /// @notice get amm address of this margin
    function amm() external view returns (address);

    /// @notice get trader's position
    function getPosition(address trader)
        external
        view
        returns (
            int256 baseSize,
            int256 quoteSize,
            uint256 tradeSize
        );

    /// @notice get withdrawable margin of trader
    function getWithdrawable(address trader) external view returns (uint256 amount);

    /// @notice check if can liquidate this trader's position
    function canLiquidate(address trader) external view returns (bool);

    /// @notice calculate the latest funding fee with current position
    function calFundingFee() external view returns (int256 fundingFee);

    /// @notice calculate the latest debt ratio with Pnl and funding fee
    function calDebtRatio(int256 quoteSize, int256 baseSize) external view returns (uint256 debtRatio);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

abstract contract Ownable {
    address public admin;
    address public pendingAdmin;

    event NewAdmin(address indexed oldAdmin, address indexed newAdmin);
    event NewPendingAdmin(address indexed oldPendingAdmin, address indexed newPendingAdmin);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Ownable: REQUIRE_ADMIN");
        _;
    }

    function setPendingAdmin(address newPendingAdmin) external onlyAdmin {
        require(pendingAdmin != newPendingAdmin, "Ownable: ALREADY_SET");
        emit NewPendingAdmin(pendingAdmin, newPendingAdmin);
        pendingAdmin = newPendingAdmin;
    }

    function acceptAdmin() external {
        require(msg.sender == pendingAdmin, "Ownable: REQUIRE_PENDING_ADMIN");
        address oldAdmin = admin;
        address oldPendingAdmin = pendingAdmin;
        admin = pendingAdmin;
        pendingAdmin = address(0);
        emit NewAdmin(oldAdmin, admin);
        emit NewPendingAdmin(oldPendingAdmin, pendingAdmin);
    }
}