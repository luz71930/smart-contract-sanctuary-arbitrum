// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (proxy/beacon/IBeacon.sol)

pragma solidity ^0.8.0;

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeaconUpgradeable {
    /**
     * @dev Must return an address that can be used as a delegate call target.
     *
     * {BeaconProxy} will check that this address is a contract.
     */
    function implementation() external view returns (address);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20Upgradeable.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20MetadataUpgradeable is IERC20Upgradeable {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../../../utils/Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

// SPDX-License-Identifier: MIT
// The line above is recommended and let you define the license of your contract
// Solidity files have to start with this pragma.
// It will be used by the Solidity compiler to validate its version.
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../../../interfaces/IConfig.sol";
import "../../../interfaces/IConfig.sol";
import "../../../interfaces/IRegistry.sol";
import "../../../interfaces/IBridge.sol";
import "../../../interfaces/socket/ISocketRegistry.sol";

abstract contract BaseBridge is IBridge {
    using SafeERC20 for IERC20Metadata;

    IConfig public immutable override config;
    IDex public immutable override dex;

    constructor(IConfig c, IDex d) {
        config = c;
        dex = d;
    }
    // non payable as we only handle stablecoins
    function outboundERC20TransferAllTo(
        BridgeAllUserRequest calldata request,
        IDex.SwapAllRequest calldata swapAllRequest,
        uint256 toAmount
    ) external override {
        require(request.receiverAddress != address(0), "BB1");
        require(request.toChainId != 0, "BB2");
        uint256 amount;
        if (address(swapAllRequest.inputToken) == address(0)) {
            amount = IERC20Metadata(request.middlewareRequest.inputToken).balanceOf(address(this));
        } else {
            (bool success, bytes memory result) = address(dex).delegatecall(abi.encodeWithSelector(dex.swapAll.selector, swapAllRequest));
            require(success, string(result));
            amount = abi.decode(result, (uint256));
        }
        require(amount > 0, "PT1");
        // TODO check to make sure outboundTransferTo always reverts if outbound is not successful
        ISocketRegistry.UserRequest memory u = ISocketRegistry.UserRequest(
            request.receiverAddress,
            request.toChainId,
            amount,
            request.middlewareRequest,
            request.bridgeRequest
        );
        _outboundERC20TransferTo(u);
        // socketReg.outboundTransferTo(request);
        emit BridgeOutbound(
            request.toChainId,
            request.receiverAddress,
            u,
            toAmount
        );
    }

    function _outboundERC20TransferTo(
        ISocketRegistry.UserRequest memory request
    ) internal virtual;
}

// SPDX-License-Identifier: MIT
// The line above is recommended and let you define the license of your contract
// Solidity files have to start with this pragma.
// It will be used by the Solidity compiler to validate its version.
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "./BaseBridge.sol";
import "../../../interfaces/IConfig.sol";
import "../../../interfaces/IRegistry.sol";
import "../../../interfaces/IBridge.sol";
import "../../../interfaces/socket/ISocketRegistry.sol";

contract Socket is BaseBridge {
    using SafeERC20 for IERC20Metadata;

    constructor(IConfig c, IDex d) BaseBridge(c, d) {}

    // non payable as we only handle stablecoins
    function _outboundERC20TransferTo(
        ISocketRegistry.UserRequest memory request
    ) internal override {
        ISocketRegistry socketReg = config.socketRegistry();
        uint256 routeId = request.middlewareRequest.id == 0 ? request.bridgeRequest.id : request.middlewareRequest.id;
        IERC20Metadata approveToken = request.middlewareRequest.id == 0 ?
            IERC20Metadata(request.bridgeRequest.inputToken) :
            IERC20Metadata(request.middlewareRequest.inputToken);
        ISocketRegistry.RouteData memory rdata = socketReg.routes(routeId);
        address approveAddr = rdata.route;
        approveToken.safeIncreaseAllowance(approveAddr, request.amount);
        socketReg.outboundTransferTo(request);
    }
}

// SPDX-License-Identifier: MIT
// The line above is recommended and let you define the license of your contract
// Solidity files have to start with this pragma.
// It will be used by the Solidity compiler to validate its version.
pragma solidity ^0.8.0;
import "./socket/ISocketRegistry.sol";
import "./IConfig.sol";
import "./ISmartAccount.sol";
import "./IDex.sol";

interface IBridge {
    event BridgeOutbound(
        uint256 indexed toChainId,
        address indexed receiverAddress,
        ISocketRegistry.UserRequest request,
        uint256 toAmount
    );

    struct BridgeAllUserRequest {
        address receiverAddress;
        uint256 toChainId;
        ISocketRegistry.MiddlewareRequest middlewareRequest;
        ISocketRegistry.BridgeRequest bridgeRequest;
    }

    function config() external view returns (IConfig);
    function dex() external view returns (IDex);

    function outboundERC20TransferAllTo(
        BridgeAllUserRequest calldata b,
        IDex.SwapAllRequest calldata swapAllRequest,
        uint256 toAmount
    ) external;
}

// SPDX-License-Identifier: MIT
// The line above is recommended and let you define the license of your contract
// Solidity files have to start with this pragma.
// It will be used by the Solidity compiler to validate its version.
pragma solidity ^0.8.0;
import "./IRegistry.sol";
import "./ISmartAccount.sol";
import "./IPortal.sol";
import "./socket/ISocketRegistry.sol";

interface IConfig {
    event PortalSet(IPortal p);
    event RegistrySet(IRegistry p);
    event SocketRegistrySet(ISocketRegistry p);
    event SmartContractFactorySet(ISmartAccountFactory p);

    function portal() external view returns (IPortal);

    function smartAccountFactory() external view returns (ISmartAccountFactory);

    function registry() external view returns (IRegistry);

    function socketRegistry() external view returns (ISocketRegistry);

    function setPortal(IPortal p) external;

    function setRegistry(IRegistry p) external;

    function setSocketRegistry(ISocketRegistry s) external;

    function setSmartAccountFactory(ISmartAccountFactory b) external;
}

// SPDX-License-Identifier: MIT
// The line above is recommended and let you define the license of your contract
// Solidity files have to start with this pragma.
// It will be used by the Solidity compiler to validate its version.
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IDex {
    struct SwapRequest {
        uint256 inputAmount;
        uint256 minOutputAmount;
        IERC20Metadata inputToken;
        IERC20Metadata outputToken;
    }
    struct SwapAllRequest {
        uint256 slippage;
        IERC20Metadata inputToken;
        IERC20Metadata outputToken;
    }
    event Swap(
        IERC20Metadata indexed inputToken,
        IERC20Metadata indexed outputToken,
        uint256 inputAmount,
        uint256 outputAmount
    );

    function swapAll(SwapAllRequest memory swapAllRequest) external returns (uint256 actualOutputAmount);
    function swap(SwapRequest memory swapRequest) external returns (uint256 actualOutputAmount);
}

// SPDX-License-Identifier: MIT
// The line above is recommended and let you define the license of your contract
// Solidity files have to start with this pragma.
// It will be used by the Solidity compiler to validate its version.
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./IConfig.sol";
import "./IInvestable.sol";

interface IFarm is IInvestable {
    event BalanceChanged(address indexed integrationAddr, IERC20Metadata indexed underlying, int256 delta);
    event TokenDeployed(address indexed integrationAddr, IERC20Metadata indexed underlying, uint256 amount);
    event TokenWithdrawn(address indexed integrationAddr, IERC20Metadata indexed underlying, uint256 amount);
    struct PositionToken {
        IERC20Metadata underlying;
        address positionToken;
    }

    function positionToken() external view returns (address);

    function numberOfUnderlying() external view returns (uint256);

    function getUnderlyings()
        external
        view
        returns (IERC20Metadata[] memory result);

    function mainToken() external view returns (IERC20Metadata);

    function underlying() external view returns (IERC20Metadata);

    function config() external view returns (IConfig);

    function deployToken(IERC20Metadata u, uint256 amountIn18) external;

    function deployTokenAll(IERC20Metadata u) external;

    function withdrawTokenAll(IERC20Metadata u) external;

    function withdrawToken(IERC20Metadata u, uint256 underlyingAmount) external;
}

// SPDX-License-Identifier: MIT
// The line above is recommended and let you define the license of your contract
// Solidity files have to start with this pragma.
// It will be used by the Solidity compiler to validate its version.
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./IConfig.sol";

interface IInvestable {
    struct Position {
        IERC20Metadata underlying;
        address positionToken;
        uint256 amount;
    }

    function position(address user) external view returns (Position[] memory);
}

// SPDX-License-Identifier: MIT
// The line above is recommended and let you define the license of your contract
// Solidity files have to start with this pragma.
// It will be used by the Solidity compiler to validate its version.
pragma solidity ^0.8.0;
import "./socket/ISocketRegistry.sol";
import "./IConfig.sol";
import "./IDex.sol";
import "./ISmartAccount.sol";

interface IPortal {
    event Outbound(
        uint256 indexed toChainId,
        address indexed receiverAddress,
        ISocketRegistry.UserRequest request,
        IDex.SwapRequest swapRequest,
        ISmartAccount.ExecuteParams execParam,
        uint256 toAmount
    );

    function config() external view returns (IConfig);
    function dex() external view returns (IDex);

    function outboundERC20TransferTo(
        ISocketRegistry.UserRequest memory b,
        IDex.SwapRequest calldata swapRequest,
        ISmartAccount.ExecuteParams calldata execParams,
        uint256 toAmount
    ) external;
}

// SPDX-License-Identifier: MIT
// The line above is recommended and let you define the license of your contract
// Solidity files have to start with this pragma.
// It will be used by the Solidity compiler to validate its version.
pragma solidity ^0.8.0;
import "./IConfig.sol";
import "./IInvestable.sol";

interface IRegistry {
    enum IntegrationType {
        Bridge,
        Farm,
        Dex
    }

    struct Integration {
        bytes11 name;
        IntegrationType integrationType;
        address integration;
    }

    struct AccountPosition {
        IRegistry.Integration integration;
        IInvestable.Position[] position;
    }

    function config() external view returns (IConfig);

    function integrationExist(address input) external view returns (bool);

    function getIntegrations() external view returns (Integration[] memory);

    function registerIntegrations(Integration[] memory input) external;

    function unregisterIntegrations(Integration[] memory dest) external;

    function portfolio(address user)
        external
        view
        returns (AccountPosition[] memory result);
}

// SPDX-License-Identifier: MIT
// The line above is recommended and let you define the license of your contract
// Solidity files have to start with this pragma.
// It will be used by the Solidity compiler to validate its version.
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/beacon/IBeaconUpgradeable.sol";
import "./IConfig.sol";
import "./IRegistry.sol";
import "./IFarm.sol";

interface ISmartAccountFactory {
    event Execute(
        address indexed signer,
        address indexed smartAccount,
        ISmartAccount.ExecuteParams x
    );

    event SmartAccountCreated(address indexed user, address smartAccountAddr);

    function beacon() external view returns (IBeaconUpgradeable);

    function config() external view returns (IConfig);

    function smartAccount(address user) external view returns (ISmartAccount);

    function precomputeAddress(address user) external view returns (address);

    function createSmartAccount(address user) external;
}

interface ISmartAccount {
    event Execute(ExecuteParams x);

    struct ExecuteParams {
        uint256 executeChainId;
        uint256 signatureChainId;
        bytes32 nonce;
        bytes32 r;
        bytes32 s;
        uint8 v;
        Operation[] operations;
    }
    struct Operation {
        address integration;
        address token;
        uint256 value;
        bytes data;
    }
    event TokenWithdrawn(
        IERC20MetadataUpgradeable indexed token,
        address indexed to,
        uint256 amount
    );

    event NativeWithdrawn(address indexed to, uint256 amount);

    function config() external view returns (IConfig);

    function withdrawToken(IERC20MetadataUpgradeable token, uint256 amountIn18)
        external;

    function withdrawNative(uint256 amountIn18) external;

    function execute(ExecuteParams calldata x) external payable;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/**
// @title Movr Regisrtry Contract.
// @notice This is the main contract that is called using fund movr.
// This contains all the bridge and middleware ids.
// RouteIds signify which bridge to be used.
// Middleware Id signifies which aggregator will be used for swapping if required.
*/
interface ISocketRegistry {
    ///@notice RouteData stores information for a route
    struct RouteData {
        address route;
        bool isEnabled;
        bool isMiddleware;
    }

    function routes(uint256) external view returns (RouteData memory);

    //
    // Events
    //
    event NewRouteAdded(
        uint256 routeID,
        address route,
        bool isEnabled,
        bool isMiddleware
    );
    event RouteDisabled(uint256 routeID);
    event ExecutionCompleted(
        uint256 middlewareID,
        uint256 bridgeID,
        uint256 inputAmount
    );

    /**
    // @param id route id of middleware to be used
    // @param optionalNativeAmount is the amount of native asset that the route requires
    // @param inputToken token address which will be swapped to
    // BridgeRequest inputToken
    // @param data to be used by middleware
    */
    struct MiddlewareRequest {
        uint256 id;
        uint256 optionalNativeAmount;
        address inputToken;
        bytes data;
    }

    /**
    // @param id route id of bridge to be used
    // @param optionalNativeAmount optinal native amount, to be used
    // when bridge needs native token along with ERC20
    // @param inputToken token addresss which will be bridged
    // @param data bridgeData to be used by bridge
    */
    struct BridgeRequest {
        uint256 id;
        uint256 optionalNativeAmount;
        address inputToken;
        bytes data;
    }

    /**
    // @param receiverAddress Recipient address to recieve funds on destination chain
    // @param toChainId Destination ChainId
    // @param amount amount to be swapped if middlewareId is 0  it will be
    // the amount to be bridged
    // @param middlewareRequest middleware Requestdata
    // @param bridgeRequest bridge request data
    */
    struct UserRequest {
        address receiverAddress;
        uint256 toChainId;
        uint256 amount;
        MiddlewareRequest middlewareRequest;
        BridgeRequest bridgeRequest;
    }

    /**
    // @notice function responsible for calling the respective implementation
    // depending on the bridge to be used
    // If the middlewareId is 0 then no swap is required,
    // we can directly bridge the source token to wherever required,
    // else, we first call the Swap Impl Base for swapping to the required
    // token and then start the bridging
    // @dev It is required for isMiddleWare to be true for route 0 as it is a special case
    // @param _userRequest calldata follows the input data struct
    */
    function outboundTransferTo(UserRequest calldata _userRequest)
        external
        payable;
}