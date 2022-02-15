pragma solidity >=0.6.2;

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

pragma solidity >=0.6.2;

import './IUniswapV2Router01.sol';

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0;

interface IController {
	function governance() external view returns (address);

	function rewards() external view returns (address);

	function withdraw(address, uint256) external;

	function balanceOf(address) external view returns (uint256);

	function earn(address, uint256) external;

	function want(address) external view returns (address);

	function vaults(address) external view returns (address);

	function strategies(address) external view returns (address);

	function approvedStrategies(address, address) external view returns (bool);

	function converters(address, address) external view returns (address);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0;

interface IConverter {
	function convert(address) external returns (uint256);

	function estimate(uint256) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0;

interface ICurvePool {
	function get_dy(
		int128,
		int128,
		uint256
	) external view returns (uint256);

	function get_dy(
		uint256,
		uint256,
		uint256
	) external view returns (uint256);

	function get_dy_underlying(
		int128,
		int128,
		uint256
	) external view returns (uint256);

	function get_dy_underlying(
		uint256,
		uint256,
		uint256
	) external view returns (uint256);

	function exchange(
		int128,
		int128,
		uint256,
		uint256
	) external;

	function exchange(
		uint256,
		uint256,
		uint256,
		uint256
	) external;

	function exchange_underlying(
		int128,
		int128,
		uint256,
		uint256
	) external;

	function exchange_underlying(
		uint256,
		uint256,
		uint256,
		uint256
	) external;

	function coins(int128) external view returns (address);

	function coins(int256) external view returns (address);

	function coins(uint128) external view returns (address);

	function coins(uint256) external view returns (address);

	function underlying_coins(int128) external view returns (address);

	function underlying_coins(uint128) external view returns (address);

	function underlying_coins(int256) external view returns (address);

	function underlying_coins(uint256) external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

interface StrategyAPI {
	function name() external view returns (string memory);

	function vault() external view returns (address);

	function nativeWrapper() external view returns (address);

	function want() external view returns (address);

	function vaultWant() external view returns (address);

	function apiVersion() external pure returns (string memory);

	function keeper() external view returns (address);

	function isActive() external view returns (bool);

	function delegatedAssets() external view returns (uint256);

	function estimatedTotalAssets() external view returns (uint256);

	function tendTrigger(uint256 callCost) external view returns (bool);

	function tend() external;

	function harvestTrigger(uint256 callCost) external view returns (bool);

	function harvest() external;

	event Harvested(uint256 profit, uint256 loss, uint256 debtPayment, uint256 debtOutstanding);
}

abstract contract IStrategy is StrategyAPI {
	function permissionedSend(address _module, uint256 _amount) external virtual returns (uint256);

	function withdrawAll() external virtual;

	function deposit() external virtual;

	function balanceOf() external view virtual returns (uint256);

	function withdraw(uint256) external virtual;

	function withdraw(address) external virtual;

	function permissionedEther(address, uint256) external virtual;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0;

interface IWETH {
	function withdraw(uint256) external;
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0;

interface IZeroModule {
	function repayLoan(
		address _to,
		address _asset,
		uint256 _actualAmount,
		uint256 _amount,
		bytes memory _data
	) external;

	function receiveLoan(
		address _to,
		address _asset,
		uint256 _actual,
		uint256 _nonce,
		bytes memory _data
	) external;

	function computeReserveRequirement(uint256 _in) external view returns (uint256);

	function want() external view returns (address);
}

pragma solidity >=0.6.0;

import {IERC20} from 'oz410/token/ERC20/IERC20.sol';

abstract contract IyVault is IERC20 {
	function pricePerShare() external view virtual returns (uint256);

	function getPricePerFullShare() external view virtual returns (uint256);

	function totalAssets() external view virtual returns (uint256);

	function deposit(uint256 _amount) external virtual returns (uint256);

	function withdraw(uint256 maxShares) external virtual returns (uint256);

	function want() external virtual returns (address);

	function decimals() external view virtual returns (uint8);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

import 'oz410/token/ERC20/IERC20.sol';
import 'oz410/math/SafeMath.sol';
import 'oz410/utils/Address.sol';
import 'oz410/token/ERC20/SafeERC20.sol';
import '../interfaces/IStrategy.sol';
import '../interfaces/IyVault.sol';
import '../interfaces/IWETH.sol';
import '../interfaces/IConverter.sol';
import {StrategyAPI} from '../interfaces/IStrategy.sol';
import {IController} from '../interfaces/IController.sol';
import {IUniswapV2Router02} from '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import {ICurvePool} from '../interfaces/ICurvePool.sol';
import {IZeroModule} from '../interfaces/IZeroModule.sol';

contract StrategyRenVMArbitrum {
	using SafeERC20 for IERC20;
	using Address for address;
	using SafeMath for uint256;

	address public immutable vault;
	address public immutable nativeWrapper;
	address public immutable want;
	int128 public constant wantIndex = 0;

	address public immutable vaultWant;
	int128 public constant vaultWantIndex = 1;

	string public constant name = '0confirmation RenVM Strategy';
	bool public constant isActive = true;

	uint256 public constant wantReserve = 1000000;
	uint256 public constant gasReserve = uint256(1e17);
	address public immutable controller;
	address public governance;
	address public strategist;

	modifier onlyController() {
		require(msg.sender == controller, '!controller');
		_;
	}

	constructor(
		address _controller,
		address _want,
		address _nativeWrapper,
		address _vault,
		address _vaultWant
	) {
		nativeWrapper = _nativeWrapper;
		want = _want;
		vault = _vault;
		vaultWant = _vaultWant;
		governance = msg.sender;
		strategist = msg.sender;
		controller = _controller;
		IERC20(_vaultWant).safeApprove(address(_vault), type(uint256).max);
	}

	receive() external payable {}

	function deposit() external virtual {
		//First conditional handles having too much of want in the Strategy
		uint256 _want = IERC20(want).balanceOf(address(this)); //amount of tokens we want
		if (_want > wantReserve) {
			// Then we can deposit excess tokens into the vault
			address converter = IController(controller).converters(want, vaultWant);
			require(converter != address(0x0), '!converter');
			uint256 _excess = _want.sub(wantReserve);
			require(IERC20(want).transfer(converter, _excess), '!transfer');
			uint256 _amountOut = IConverter(converter).convert(address(0x0));
			IyVault(vault).deposit(_amountOut);
		}
		//Second conditional handles having too little of gasWant in the Strategy

		uint256 _gasWant = address(this).balance; //ETH balance
		if (_gasWant < gasReserve) {
			// if ETH balance < ETH reserve
			_gasWant = gasReserve.sub(_gasWant);
			address _converter = IController(controller).converters(nativeWrapper, vaultWant);
			uint256 _vaultWant = IConverter(_converter).estimate(_gasWant); //_gasWant is estimated from wETH to wBTC
			uint256 _sharesDeficit = estimateShares(_vaultWant); //Estimate shares of wBTC
			// Works up to this point
			require(IERC20(vault).balanceOf(address(this)) > _sharesDeficit, '!enough'); //revert if shares needed > shares held
			uint256 _amountOut = IyVault(vault).withdraw(_sharesDeficit);
			address converter = IController(controller).converters(vaultWant, nativeWrapper);
			IERC20(vaultWant).transfer(converter, _amountOut);
			_amountOut = IConverter(converter).convert(address(this));
			address _unwrapper = IController(controller).converters(nativeWrapper, address(0x0));
			IERC20(nativeWrapper).transfer(_unwrapper, _amountOut);
			IConverter(_unwrapper).convert(address(this));
		}
	}

	function _withdraw(uint256 _amount, address _asset) private returns (uint256) {
		require(_asset == want || _asset == vaultWant, 'asset not supported');
		if (_amount == 0) {
			return 0;
		}
		address converter = IController(controller).converters(want, vaultWant);
		// _asset is wBTC and want is renBTC
		if (_asset == want) {
			// if asset is what the strategy wants
			//then we can't directly withdraw it
			_amount = IConverter(converter).estimate(_amount);
		}
		uint256 _shares = estimateShares(_amount);
		_amount = IyVault(vault).withdraw(_shares);
		if (_asset == want) {
			// if asset is what the strategy wants
      IConverter toWant = IConverter(IController(controller).converters(vaultWant, want));
			IERC20(vaultWant).transfer(address(toWant), _amount);
			_amount = toWant.convert(address(0x0));
		}
		return _amount;
	}

	function permissionedEther(address payable _target, uint256 _amount) external virtual onlyController {
		// _amount is the amount of ETH to refund
		if (_amount > gasReserve) {
			_amount = IConverter(IController(controller).converters(nativeWrapper, vaultWant)).estimate(_amount);
			uint256 _sharesDeficit = estimateShares(_amount);
			uint256 _amountOut = IyVault(vault).withdraw(_sharesDeficit);
			address _vaultConverter = IController(controller).converters(vaultWant, nativeWrapper);
			address _converter = IController(controller).converters(nativeWrapper, address(0x0));
			IERC20(vaultWant).transfer(_vaultConverter, _amountOut);
			_amount = IConverter(_vaultConverter).convert(address(this));
			IERC20(nativeWrapper).transfer(_converter, _amount);
			_amount = IConverter(_converter).convert(address(this));
		}
		_target.transfer(_amount);
	}

	function withdraw(uint256 _amount) external virtual onlyController {
		IERC20(want).safeTransfer(address(controller), _withdraw(_amount, want));
	}

	function withdrawAll() external virtual onlyController {
		IERC20(want).safeTransfer(address(controller), _withdraw(IERC20(vault).balanceOf(address(this)), want));
	}

	function balanceOf() external view virtual returns (uint256) {
		return IyVault(vault).balanceOf(address(this));
	}

	function estimateShares(uint256 _amount) internal virtual returns (uint256) {
		return _amount.mul(10**IyVault(vault).decimals()).div(IyVault(vault).pricePerShare());
	}

	function permissionedSend(address _module, uint256 _amount) external virtual onlyController returns (uint256) {
		uint256 _reserve = IERC20(want).balanceOf(address(this));
		address _want = IZeroModule(_module).want();
		if (_amount > _reserve || _want != want) {
			_amount = _withdraw(_amount, _want);
		}
		IERC20(_want).safeTransfer(_module, _amount);
		return _amount;
	}
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a % b);
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: modulo by zero");
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryDiv}.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a % b;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

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
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

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

pragma solidity ^0.7.0;

import "./IERC20.sol";
import "../../math/SafeMath.sol";
import "../../utils/Address.sol";

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
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeERC20: decreased allowance below zero");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
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
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

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
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
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

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
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
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
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
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
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