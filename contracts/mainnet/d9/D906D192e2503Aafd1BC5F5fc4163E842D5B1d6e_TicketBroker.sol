// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/cryptography/ECDSA.sol)

pragma solidity ^0.8.0;

import "../Strings.sol";

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSA {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS,
        InvalidSignatureV
    }

    function _throwError(RecoverError error) private pure {
        if (error == RecoverError.NoError) {
            return; // no error: do nothing
        } else if (error == RecoverError.InvalidSignature) {
            revert("ECDSA: invalid signature");
        } else if (error == RecoverError.InvalidSignatureLength) {
            revert("ECDSA: invalid signature length");
        } else if (error == RecoverError.InvalidSignatureS) {
            revert("ECDSA: invalid signature 's' value");
        } else if (error == RecoverError.InvalidSignatureV) {
            revert("ECDSA: invalid signature 'v' value");
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature` or error string. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     *
     * Documentation for signature generation:
     * - with https://web3js.readthedocs.io/en/v1.3.4/web3-eth-accounts.html#sign[Web3.js]
     * - with https://docs.ethers.io/v5/api/signer/#Signer-signMessage[ethers]
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, bytes memory signature) internal pure returns (address, RecoverError) {
        // Check the signature length
        // - case 65: r,s,v signature (standard)
        // - case 64: r,vs signature (cf https://eips.ethereum.org/EIPS/eip-2098) _Available since v4.1._
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else if (signature.length == 64) {
            bytes32 r;
            bytes32 vs;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            assembly {
                r := mload(add(signature, 0x20))
                vs := mload(add(signature, 0x40))
            }
            return tryRecover(hash, r, vs);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength);
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, signature);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `r` and `vs` short-signature fields separately.
     *
     * See https://eips.ethereum.org/EIPS/eip-2098[EIP-2098 short signatures]
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address, RecoverError) {
        bytes32 s;
        uint8 v;
        assembly {
            s := and(vs, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
            v := add(shr(255, vs), 27)
        }
        return tryRecover(hash, v, r, s);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `r and `vs` short-signature fields separately.
     *
     * _Available since v4.2._
     */
    function recover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, r, vs);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `v`,
     * `r` and `s` signature fields separately.
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address, RecoverError) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return (address(0), RecoverError.InvalidSignatureS);
        }
        if (v != 27 && v != 28) {
            return (address(0), RecoverError.InvalidSignatureV);
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature);
        }

        return (signer, RecoverError.NoError);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, v, r, s);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from a `hash`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        // 32 is the length in bytes of hash,
        // enforced by the type signature above
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from `s`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", Strings.toString(s.length), s));
    }

    /**
     * @dev Returns an Ethereum Signed Typed Data, created from a
     * `domainSeparator` and a `structHash`. This produces hash corresponding
     * to the one signed with the
     * https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`]
     * JSON-RPC method as part of EIP-712.
     *
     * See {recover}.
     */
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/math/SafeMath.sol)

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
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
        return a + b;
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
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
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
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
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
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
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
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./zeppelin/Pausable.sol";

abstract contract IController is Pausable {
    event SetContractInfo(bytes32 id, address contractAddress, bytes20 gitCommitHash);

    function setContractInfo(
        bytes32 _id,
        address _contractAddress,
        bytes20 _gitCommitHash
    ) external virtual;

    function updateController(bytes32 _id, address _controller) external virtual;

    function getContract(bytes32 _id) public view virtual returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface IManager {
    event SetController(address controller);
    event ParameterUpdate(string param);

    function setController(address _controller) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./IManager.sol";
import "./IController.sol";

contract Manager is IManager {
    // Controller that contract is registered with
    IController public controller;

    // Check if sender is controller
    modifier onlyController() {
        _onlyController();
        _;
    }

    // Check if sender is controller owner
    modifier onlyControllerOwner() {
        _onlyControllerOwner();
        _;
    }

    // Check if controller is not paused
    modifier whenSystemNotPaused() {
        _whenSystemNotPaused();
        _;
    }

    // Check if controller is paused
    modifier whenSystemPaused() {
        _whenSystemPaused();
        _;
    }

    constructor(address _controller) {
        controller = IController(_controller);
    }

    /**
     * @notice Set controller. Only callable by current controller
     * @param _controller Controller contract address
     */
    function setController(address _controller) external onlyController {
        controller = IController(_controller);

        emit SetController(_controller);
    }

    function _onlyController() private view {
        require(msg.sender == address(controller), "caller must be Controller");
    }

    function _onlyControllerOwner() private view {
        require(msg.sender == controller.owner(), "caller must be Controller owner");
    }

    function _whenSystemNotPaused() private view {
        require(!controller.paused(), "system is paused");
    }

    function _whenSystemPaused() private view {
        require(controller.paused(), "system is not paused");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./Manager.sol";

/**
 * @title ManagerProxyTarget
 * @notice The base contract that target contracts used by a proxy contract should inherit from
 * @dev Both the target contract and the proxy contract (implemented as ManagerProxy) MUST inherit from ManagerProxyTarget in order to guarantee
 that both contracts have the same storage layout. Differing storage layouts in a proxy contract and target contract can
 potentially break the delegate proxy upgradeability mechanism
 */
abstract contract ManagerProxyTarget is Manager {
    // Used to look up target contract address in controller's registry
    bytes32 public targetContractId;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

/**
 * @title Interface for BondingManager
 * TODO: switch to interface type
 */
interface IBondingManager {
    event TranscoderUpdate(address indexed transcoder, uint256 rewardCut, uint256 feeShare);
    event TranscoderActivated(address indexed transcoder, uint256 activationRound);
    event TranscoderDeactivated(address indexed transcoder, uint256 deactivationRound);
    event TranscoderSlashed(address indexed transcoder, address finder, uint256 penalty, uint256 finderReward);
    event Reward(address indexed transcoder, uint256 amount);
    event Bond(
        address indexed newDelegate,
        address indexed oldDelegate,
        address indexed delegator,
        uint256 additionalAmount,
        uint256 bondedAmount
    );
    event Unbond(
        address indexed delegate,
        address indexed delegator,
        uint256 unbondingLockId,
        uint256 amount,
        uint256 withdrawRound
    );
    event Rebond(address indexed delegate, address indexed delegator, uint256 unbondingLockId, uint256 amount);
    event TransferBond(
        address indexed oldDelegator,
        address indexed newDelegator,
        uint256 oldUnbondingLockId,
        uint256 newUnbondingLockId,
        uint256 amount
    );
    event WithdrawStake(address indexed delegator, uint256 unbondingLockId, uint256 amount, uint256 withdrawRound);
    event WithdrawFees(address indexed delegator, address recipient, uint256 amount);
    event EarningsClaimed(
        address indexed delegate,
        address indexed delegator,
        uint256 rewards,
        uint256 fees,
        uint256 startRound,
        uint256 endRound
    );

    // Deprecated events
    // These event signatures can be used to construct the appropriate topic hashes to filter for past logs corresponding
    // to these deprecated events.
    // event Bond(address indexed delegate, address indexed delegator);
    // event Unbond(address indexed delegate, address indexed delegator);
    // event WithdrawStake(address indexed delegator);
    // event TranscoderUpdate(address indexed transcoder, uint256 pendingRewardCut, uint256 pendingFeeShare, uint256 pendingPricePerSegment, bool registered);
    // event TranscoderEvicted(address indexed transcoder);
    // event TranscoderResigned(address indexed transcoder);

    // External functions
    function updateTranscoderWithFees(
        address _transcoder,
        uint256 _fees,
        uint256 _round
    ) external;

    function slashTranscoder(
        address _transcoder,
        address _finder,
        uint256 _slashAmount,
        uint256 _finderFee
    ) external;

    function setCurrentRoundTotalActiveStake() external;

    // Public functions
    function getTranscoderPoolSize() external view returns (uint256);

    function transcoderTotalStake(address _transcoder) external view returns (uint256);

    function isActiveTranscoder(address _transcoder) external view returns (bool);

    function getTotalBonded() external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./mixins/MixinContractRegistry.sol";
import "./mixins/MixinReserve.sol";
import "./mixins/MixinTicketBrokerCore.sol";
import "./mixins/MixinTicketProcessor.sol";
import "./mixins/MixinWrappers.sol";

contract TicketBroker is
    MixinContractRegistry,
    MixinReserve,
    MixinTicketBrokerCore,
    MixinTicketProcessor,
    MixinWrappers
{
    /**
     * @notice TicketBroker constructor. Only invokes constructor of base Manager contract with provided Controller address
     * @dev This constructor will not initialize any state variables besides `controller`. The following setter functions
     * should be used to initialize state variables post-deployment:
     * - setUnlockPeriod()
     * - setTicketValidityPeriod()
     * @param _controller Address of Controller that this contract will be registered with
     */
    constructor(address _controller)
        MixinContractRegistry(_controller)
        MixinReserve()
        MixinTicketBrokerCore()
        MixinTicketProcessor()
    {}

    /**
     * @notice Sets unlockPeriod value. Only callable by the Controller owner
     * @param _unlockPeriod Value for unlockPeriod
     */
    function setUnlockPeriod(uint256 _unlockPeriod) external onlyControllerOwner {
        unlockPeriod = _unlockPeriod;

        emit ParameterUpdate("unlockPeriod");
    }

    /**
     * @notice Sets ticketValidityPeriod value. Only callable by the Controller owner
     * @param _ticketValidityPeriod Value for ticketValidityPeriod
     */
    function setTicketValidityPeriod(uint256 _ticketValidityPeriod) external onlyControllerOwner {
        require(_ticketValidityPeriod > 0, "ticketValidityPeriod must be greater than 0");

        ticketValidityPeriod = _ticketValidityPeriod;

        emit ParameterUpdate("ticketValidityPeriod");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../ManagerProxyTarget.sol";
import "./interfaces/MContractRegistry.sol";

abstract contract MixinContractRegistry is MContractRegistry, ManagerProxyTarget {
    /**
     * @dev Checks if the current round has been initialized
     */
    modifier currentRoundInitialized() override {
        require(roundsManager().currentRoundInitialized(), "current round is not initialized");
        _;
    }

    constructor(address _controller) Manager(_controller) {}

    /**
     * @dev Returns an instance of the IBondingManager interface
     */
    function bondingManager() internal view override returns (IBondingManager) {
        return IBondingManager(controller.getContract(keccak256("BondingManager")));
    }

    /**
     * @dev Returns an instance of the IMinter interface
     */
    function minter() internal view override returns (IMinter) {
        return IMinter(controller.getContract(keccak256("Minter")));
    }

    /**
     * @dev Returns an instance of the IRoundsManager interface
     */
    function roundsManager() internal view override returns (IRoundsManager) {
        return IRoundsManager(controller.getContract(keccak256("RoundsManager")));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./interfaces/MReserve.sol";
import "./MixinContractRegistry.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

abstract contract MixinReserve is MixinContractRegistry, MReserve {
    using SafeMath for uint256;

    struct Reserve {
        uint256 funds; // Amount of funds in the reserve
        mapping(uint256 => uint256) claimedForRound; // Mapping of round => total amount claimed
        mapping(uint256 => mapping(address => uint256)) claimedByAddress; // Mapping of round => claimant address => amount claimed
    }

    // Mapping of address => reserve
    mapping(address => Reserve) internal reserves;

    /**
     * @dev Returns info about a reserve
     * @param _reserveHolder Address of reserve holder
     * @return info Info about the reserve for `_reserveHolder`
     */
    function getReserveInfo(address _reserveHolder) public view override returns (ReserveInfo memory info) {
        info.fundsRemaining = remainingReserve(_reserveHolder);
        info.claimedInCurrentRound = reserves[_reserveHolder].claimedForRound[roundsManager().currentRound()];
    }

    /**
     * @dev Returns the amount of funds claimable by a claimant from a reserve in the current round
     * @param _reserveHolder Address of reserve holder
     * @param _claimant Address of claimant
     * @return Amount of funds claimable by `_claimant` from the reserve for `_reserveHolder` in the current round
     */
    function claimableReserve(address _reserveHolder, address _claimant) public view returns (uint256) {
        Reserve storage reserve = reserves[_reserveHolder];

        uint256 currentRound = roundsManager().currentRound();

        if (!bondingManager().isActiveTranscoder(_claimant)) {
            return 0;
        }

        uint256 poolSize = bondingManager().getTranscoderPoolSize();
        if (poolSize == 0) {
            return 0;
        }

        // Total claimable funds = remaining funds + amount claimed for the round
        uint256 totalClaimable = reserve.funds.add(reserve.claimedForRound[currentRound]);
        return totalClaimable.div(poolSize).sub(reserve.claimedByAddress[currentRound][_claimant]);
    }

    /**
     * @dev Returns the amount of funds claimed by a claimant from a reserve in the current round
     * @param _reserveHolder Address of reserve holder
     * @param _claimant Address of claimant
     * @return Amount of funds claimed by `_claimant` from the reserve for `_reserveHolder` in the current round
     */
    function claimedReserve(address _reserveHolder, address _claimant) public view override returns (uint256) {
        Reserve storage reserve = reserves[_reserveHolder];
        uint256 currentRound = roundsManager().currentRound();
        return reserve.claimedByAddress[currentRound][_claimant];
    }

    /**
     * @dev Adds funds to a reserve
     * @param _reserveHolder Address of reserve holder
     * @param _amount Amount of funds to add to reserve
     */
    function addReserve(address _reserveHolder, uint256 _amount) internal override {
        reserves[_reserveHolder].funds = reserves[_reserveHolder].funds.add(_amount);

        emit ReserveFunded(_reserveHolder, _amount);
    }

    /**
     * @dev Clears contract storage used for a reserve
     * @param _reserveHolder Address of reserve holder
     */
    function clearReserve(address _reserveHolder) internal override {
        // This delete operation will only clear reserve.funds and will not clear the storage for reserve.claimedForRound
        // reserve.claimedByAddress because these fields are mappings and the Solidity `delete` keyword will not modify mappings.
        // This *could* be a problem in the following scenario:
        //
        // 1) In round N, for address A, reserve.claimedForRound[N] > 0 and reserve.claimedByAddress[N][r_i] > 0 where r_i is
        // a member of the active set in round N
        // 2) This function is called by MixinTicketBrokerCore.withdraw() in round N
        // 3) Address A funds its reserve again
        //
        // After step 3, A has reserve.funds > 0, reserve.claimedForRound[N] > 0 and reserve.claimedByAddress[N][r_i] > 0
        // despite having funded a fresh reserve after previously withdrawing all of its funds in the same round.
        // We prevent this scenario by disallowing reserve claims starting at an address' withdraw round in
        // MixinTicketBrokerCore.redeemWinningTicket()
        delete reserves[_reserveHolder];
    }

    /**
     * @dev Claims funds from a reserve
     * @param _reserveHolder Address of reserve holder
     * @param _claimant Address of claimant
     * @param _amount Amount of funds to claim from the reserve
     * @return Amount of funds (<= `_amount`) claimed by `_claimant` from the reserve for `_reserveHolder`
     */
    function claimFromReserve(
        address _reserveHolder,
        address _claimant,
        uint256 _amount
    ) internal override returns (uint256) {
        uint256 claimableFunds = claimableReserve(_reserveHolder, _claimant);
        // If the given amount > claimableFunds then claim claimableFunds
        // If the given amount <= claimableFunds then claim the given amount
        uint256 claimAmount = _amount > claimableFunds ? claimableFunds : _amount;

        if (claimAmount > 0) {
            uint256 currentRound = roundsManager().currentRound();
            Reserve storage reserve = reserves[_reserveHolder];
            // Increase total amount claimed for the round
            reserve.claimedForRound[currentRound] = reserve.claimedForRound[currentRound].add(claimAmount);
            // Increase amount claimed by claimant for the round
            reserve.claimedByAddress[currentRound][_claimant] = reserve.claimedByAddress[currentRound][_claimant].add(
                claimAmount
            );
            // Decrease remaining reserve
            reserve.funds = reserve.funds.sub(claimAmount);

            emit ReserveClaimed(_reserveHolder, _claimant, claimAmount);
        }

        return claimAmount;
    }

    /**
     * @dev Returns the amount of funds remaining in a reserve
     * @param _reserveHolder Address of reserve holder
     * @return Amount of funds remaining in the reserve for `_reserveHolder`
     */
    function remainingReserve(address _reserveHolder) internal view override returns (uint256) {
        return reserves[_reserveHolder].funds;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./interfaces/MReserve.sol";
import "./interfaces/MTicketProcessor.sol";
import "./interfaces/MTicketBrokerCore.sol";
import "./MixinContractRegistry.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

abstract contract MixinTicketBrokerCore is MixinContractRegistry, MReserve, MTicketProcessor, MTicketBrokerCore {
    using SafeMath for uint256;

    struct Sender {
        uint256 deposit; // Amount of funds deposited
        uint256 withdrawRound; // Round that sender can withdraw deposit & reserve
    }

    // Mapping of address => Sender
    mapping(address => Sender) internal senders;

    // Number of rounds before a sender can withdraw after requesting an unlock
    uint256 public unlockPeriod;

    // Mapping of ticket hashes => boolean indicating if ticket was redeemed
    mapping(bytes32 => bool) public usedTickets;

    // Checks if msg.value is equal to the given deposit and reserve amounts
    modifier checkDepositReserveETHValueSplit(uint256 _depositAmount, uint256 _reserveAmount) {
        require(
            msg.value == _depositAmount.add(_reserveAmount),
            "msg.value does not equal sum of deposit amount and reserve amount"
        );

        _;
    }

    // Process deposit funding
    modifier processDeposit(address _sender, uint256 _amount) {
        Sender storage sender = senders[_sender];
        sender.deposit = sender.deposit.add(_amount);
        if (_isUnlockInProgress(sender)) {
            _cancelUnlock(sender, _sender);
        }

        _;

        emit DepositFunded(_sender, _amount);
    }

    // Process reserve funding
    modifier processReserve(address _sender, uint256 _amount) {
        Sender storage sender = senders[_sender];
        addReserve(_sender, _amount);
        if (_isUnlockInProgress(sender)) {
            _cancelUnlock(sender, _sender);
        }

        _;
    }

    /**
     * @notice Adds ETH to the caller's deposit
     */
    function fundDeposit() external payable whenSystemNotPaused processDeposit(msg.sender, msg.value) {
        processFunding(msg.value);
    }

    /**
     * @notice Adds ETH to the caller's reserve
     */
    function fundReserve() external payable whenSystemNotPaused processReserve(msg.sender, msg.value) {
        processFunding(msg.value);
    }

    /**
     * @notice Adds ETH to the caller's deposit and reserve
     * @param _depositAmount Amount of ETH to add to the caller's deposit
     * @param _reserveAmount Amount of ETH to add to the caller's reserve
     */
    function fundDepositAndReserve(uint256 _depositAmount, uint256 _reserveAmount) external payable {
        fundDepositAndReserveFor(msg.sender, _depositAmount, _reserveAmount);
    }

    /**
     * @notice Adds ETH to the address' deposit and reserve
     * @param _depositAmount Amount of ETH to add to the address' deposit
     * @param _reserveAmount Amount of ETH to add to the address' reserve
     */
    function fundDepositAndReserveFor(
        address _addr,
        uint256 _depositAmount,
        uint256 _reserveAmount
    )
        public
        payable
        whenSystemNotPaused
        checkDepositReserveETHValueSplit(_depositAmount, _reserveAmount)
        processDeposit(_addr, _depositAmount)
        processReserve(_addr, _reserveAmount)
    {
        processFunding(msg.value);
    }

    /**
     * @notice Redeems a winning ticket that has been signed by a sender and reveals the
     recipient recipientRand that corresponds to the recipientRandHash included in the ticket
     * @param _ticket Winning ticket to be redeemed in order to claim payment
     * @param _sig Sender's signature over the hash of `_ticket`
     * @param _recipientRand The preimage for the recipientRandHash included in `_ticket`
     */
    function redeemWinningTicket(
        Ticket memory _ticket,
        bytes memory _sig,
        uint256 _recipientRand
    ) public whenSystemNotPaused currentRoundInitialized {
        bytes32 ticketHash = getTicketHash(_ticket);

        // Require a valid winning ticket for redemption
        requireValidWinningTicket(_ticket, ticketHash, _sig, _recipientRand);

        Sender storage sender = senders[_ticket.sender];

        // Require sender to be locked
        require(isLocked(sender), "sender is unlocked");
        // Require either a non-zero deposit or non-zero reserve for the sender
        require(sender.deposit > 0 || remainingReserve(_ticket.sender) > 0, "sender deposit and reserve are zero");

        // Mark ticket as used to prevent replay attacks involving redeeming
        // the same winning ticket multiple times
        usedTickets[ticketHash] = true;

        uint256 amountToTransfer;

        if (_ticket.faceValue > sender.deposit) {
            // If ticket face value > sender's deposit then claim from
            // the sender's reserve

            amountToTransfer = sender.deposit.add(
                claimFromReserve(_ticket.sender, _ticket.recipient, _ticket.faceValue.sub(sender.deposit))
            );

            sender.deposit = 0;
        } else {
            // If ticket face value <= sender's deposit then only deduct
            // from sender's deposit

            amountToTransfer = _ticket.faceValue;
            sender.deposit = sender.deposit.sub(_ticket.faceValue);
        }

        if (amountToTransfer > 0) {
            winningTicketTransfer(_ticket.recipient, amountToTransfer, _ticket.auxData);

            emit WinningTicketTransfer(_ticket.sender, _ticket.recipient, amountToTransfer);
        }

        emit WinningTicketRedeemed(
            _ticket.sender,
            _ticket.recipient,
            _ticket.faceValue,
            _ticket.winProb,
            _ticket.senderNonce,
            _recipientRand,
            _ticket.auxData
        );
    }

    /**
     * @notice Initiates the unlock period for the caller
     */
    function unlock() public whenSystemNotPaused {
        Sender storage sender = senders[msg.sender];

        require(sender.deposit > 0 || remainingReserve(msg.sender) > 0, "sender deposit and reserve are zero");
        require(!_isUnlockInProgress(sender), "unlock already initiated");

        uint256 currentRound = roundsManager().currentRound();
        sender.withdrawRound = currentRound.add(unlockPeriod);

        emit Unlock(msg.sender, currentRound, sender.withdrawRound);
    }

    /**
     * @notice Cancels the unlock period for the caller
     */
    function cancelUnlock() public whenSystemNotPaused {
        Sender storage sender = senders[msg.sender];

        _cancelUnlock(sender, msg.sender);
    }

    /**
     * @notice Withdraws all ETH from the caller's deposit and reserve
     */
    function withdraw() public whenSystemNotPaused {
        Sender storage sender = senders[msg.sender];

        uint256 deposit = sender.deposit;
        uint256 reserve = remainingReserve(msg.sender);

        require(deposit > 0 || reserve > 0, "sender deposit and reserve are zero");
        require(_isUnlockInProgress(sender), "no unlock request in progress");
        require(!isLocked(sender), "account is locked");

        sender.deposit = 0;
        clearReserve(msg.sender);

        withdrawTransfer(payable(msg.sender), deposit.add(reserve));

        emit Withdrawal(msg.sender, deposit, reserve);
    }

    /**
     * @notice Returns whether a sender is currently in the unlock period
     * @param _sender Address of sender
     * @return Boolean indicating whether `_sender` has an unlock in progress
     */
    function isUnlockInProgress(address _sender) public view returns (bool) {
        Sender memory sender = senders[_sender];
        return _isUnlockInProgress(sender);
    }

    /**
     * @notice Returns info about a sender
     * @param _sender Address of sender
     * @return sender Info about the sender for `_sender`
     * @return reserve Info about the reserve for `_sender`
     */
    function getSenderInfo(address _sender) public view returns (Sender memory sender, ReserveInfo memory reserve) {
        sender = senders[_sender];
        reserve = getReserveInfo(_sender);
    }

    /**
     * @dev Returns the hash of a ticket
     * @param _ticket Ticket to be hashed
     * @return keccak256 hash of `_ticket`
     */
    function getTicketHash(Ticket memory _ticket) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    _ticket.recipient,
                    _ticket.sender,
                    _ticket.faceValue,
                    _ticket.winProb,
                    _ticket.senderNonce,
                    _ticket.recipientRandHash,
                    _ticket.auxData
                )
            );
    }

    /**
     * @dev Helper to cancel an unlock
     * @param _sender Sender that is cancelling an unlock
     * @param _senderAddress Address of sender
     */
    function _cancelUnlock(Sender storage _sender, address _senderAddress) internal {
        require(_isUnlockInProgress(_sender), "no unlock request in progress");

        _sender.withdrawRound = 0;

        emit UnlockCancelled(_senderAddress);
    }

    /**
     * @dev Validates a winning ticket, succeeds or reverts
     * @param _ticket Winning ticket to be validated
     * @param _ticketHash Hash of `_ticket`
     * @param _sig Sender's signature over `_ticketHash`
     * @param _recipientRand The preimage for the recipientRandHash included in `_ticket`
     */
    function requireValidWinningTicket(
        Ticket memory _ticket,
        bytes32 _ticketHash,
        bytes memory _sig,
        uint256 _recipientRand
    ) internal view {
        require(_ticket.recipient != address(0), "ticket recipient is null address");
        require(_ticket.sender != address(0), "ticket sender is null address");

        requireValidTicketAuxData(_ticket.auxData);

        require(
            keccak256(abi.encodePacked(_recipientRand)) == _ticket.recipientRandHash,
            "recipientRand does not match recipientRandHash"
        );

        require(!usedTickets[_ticketHash], "ticket is used");

        require(isValidTicketSig(_ticket.sender, _sig, _ticketHash), "invalid signature over ticket hash");

        require(isWinningTicket(_sig, _recipientRand, _ticket.winProb), "ticket did not win");
    }

    /**
     * @dev Returns whether a sender is locked
     * @param _sender Sender to check for locked status
     * @return Boolean indicating whether sender is currently locked
     */
    function isLocked(Sender memory _sender) internal view returns (bool) {
        return _sender.withdrawRound == 0 || roundsManager().currentRound() < _sender.withdrawRound;
    }

    /**
     * @dev Returns whether a signature over a ticket hash is valid for a sender
     * @param _sender Address of sender
     * @param _sig Signature over `_ticketHash`
     * @param _ticketHash Hash of the ticket
     * @return Boolean indicating whether `_sig` is valid signature over `_ticketHash` for `_sender`
     */
    function isValidTicketSig(
        address _sender,
        bytes memory _sig,
        bytes32 _ticketHash
    ) internal pure returns (bool) {
        require(_sig.length == 65, "INVALID_SIGNATURE_LENGTH");
        address signer = ECDSA.recover(ECDSA.toEthSignedMessageHash(_ticketHash), _sig);
        return signer != address(0) && _sender == signer;
    }

    /**
     * @dev Returns whether a ticket won
     * @param _sig Sender's signature over the ticket
     * @param _recipientRand The preimage for the recipientRandHash included in the ticket
     * @param _winProb The winning probability of the ticket
     * @return Boolean indicating whether the ticket won
     */
    function isWinningTicket(
        bytes memory _sig,
        uint256 _recipientRand,
        uint256 _winProb
    ) internal pure returns (bool) {
        return uint256(keccak256(abi.encodePacked(_sig, _recipientRand))) < _winProb;
    }

    /**
     * @dev Helper to check if a sender is currently in the unlock period
     * @param _sender Sender to check for an unlock
     * @return Boolean indicating whether the sender is currently in the unlock period
     */
    function _isUnlockInProgress(Sender memory _sender) internal pure returns (bool) {
        return _sender.withdrawRound > 0;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./interfaces/MTicketProcessor.sol";
import "./MixinContractRegistry.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

abstract contract MixinTicketProcessor is MixinContractRegistry, MTicketProcessor {
    using SafeMath for uint256;

    // Number of rounds that a ticket is valid for starting from
    // its creationRound
    uint256 public ticketValidityPeriod;

    /**
     * @dev Process sent funds.
     * @param _amount Amount of funds sent
     */
    function processFunding(uint256 _amount) internal override {
        // Send funds to Minter
        minter().depositETH{ value: _amount }();
    }

    /**
     * @dev Transfer withdrawal funds for a ticket sender
     * @param _amount Amount of withdrawal funds
     */
    function withdrawTransfer(address payable _sender, uint256 _amount) internal override {
        // Ask Minter to send withdrawal funds to the ticket sender
        minter().trustedWithdrawETH(_sender, _amount);
    }

    /**
     * @dev Transfer funds for a recipient's winning ticket
     * @param _recipient Address of recipient
     * @param _amount Amount of funds for the winning ticket
     * @param _auxData Auxilary data for the winning ticket
     */
    function winningTicketTransfer(
        address _recipient,
        uint256 _amount,
        bytes memory _auxData
    ) internal override {
        (uint256 creationRound, ) = getCreationRoundAndBlockHash(_auxData);

        // Ask BondingManager to update fee pool for recipient with
        // winning ticket funds
        bondingManager().updateTranscoderWithFees(_recipient, _amount, creationRound);
    }

    /**
     * @dev Validates a ticket's auxilary data (succeeds or reverts)
     * @param _auxData Auxilary data inclueded in a ticket
     */
    function requireValidTicketAuxData(bytes memory _auxData) internal view override {
        (uint256 creationRound, bytes32 creationRoundBlockHash) = getCreationRoundAndBlockHash(_auxData);
        bytes32 blockHash = roundsManager().blockHashForRound(creationRound);

        require(blockHash != bytes32(0), "ticket creationRound does not have a block hash");
        require(creationRoundBlockHash == blockHash, "ticket creationRoundBlockHash invalid for creationRound");

        uint256 currRound = roundsManager().currentRound();

        require(creationRound.add(ticketValidityPeriod) > currRound, "ticket is expired");
    }

    /**
     * @dev Returns a ticket's creationRound and creationRoundBlockHash parsed from ticket auxilary data
     * @param _auxData Auxilary data for a ticket
     * @return creationRound and creationRoundBlockHash parsed from `_auxData`
     */
    function getCreationRoundAndBlockHash(bytes memory _auxData)
        internal
        pure
        returns (uint256 creationRound, bytes32 creationRoundBlockHash)
    {
        require(_auxData.length == 64, "invalid length for ticket auxData: must be 64 bytes");

        // _auxData format:
        // Bytes [0:31] = creationRound
        // Bytes [32:63] = creationRoundBlockHash
        assembly {
            creationRound := mload(add(_auxData, 32))
            creationRoundBlockHash := mload(add(_auxData, 64))
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./interfaces/MTicketBrokerCore.sol";
import "./MixinContractRegistry.sol";

abstract contract MixinWrappers is MixinContractRegistry, MTicketBrokerCore {
    /**
     * @notice Redeems multiple winning tickets. The function will redeem all of the provided tickets and handle any failures gracefully without reverting the entire function
     * @param _tickets Array of winning tickets to be redeemed in order to claim payment
     * @param _sigs Array of sender signatures over the hash of tickets (`_sigs[i]` corresponds to `_tickets[i]`)
     * @param _recipientRands Array of preimages for the recipientRandHash included in each ticket (`_recipientRands[i]` corresponds to `_tickets[i]`)
     */
    function batchRedeemWinningTickets(
        Ticket[] memory _tickets,
        bytes[] memory _sigs,
        uint256[] memory _recipientRands
    ) public whenSystemNotPaused currentRoundInitialized {
        for (uint256 i = 0; i < _tickets.length; i++) {
            redeemWinningTicketNoRevert(_tickets[i], _sigs[i], _recipientRands[i]);
        }
    }

    /**
     * @dev Redeems a winning ticket that has been signed by a sender and reveals the
     recipient recipientRand that corresponds to the recipientRandHash included in the ticket
     This function wraps `redeemWinningTicket()` and returns false if the underlying call reverts
     * @param _ticket Winning ticket to be redeemed in order to claim payment
     * @param _sig Sender's signature over the hash of `_ticket`
     * @param _recipientRand The preimage for the recipientRandHash included in `_ticket`
     * @return success Boolean indicating whether the underlying `redeemWinningTicket()` call succeeded
     */
    function redeemWinningTicketNoRevert(
        Ticket memory _ticket,
        bytes memory _sig,
        uint256 _recipientRand
    ) internal returns (bool success) {
        // ABI encode calldata for `redeemWinningTicket()`
        // A tuple type is used to represent the Ticket struct in the function signature
        bytes memory redeemWinningTicketCalldata = abi.encodeWithSignature(
            "redeemWinningTicket((address,address,uint256,uint256,uint256,bytes32,bytes),bytes,uint256)",
            _ticket,
            _sig,
            _recipientRand
        );

        // Call `redeemWinningTicket()`
        // solium-disable-next-line
        (success, ) = address(this).call(redeemWinningTicketCalldata);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../../bonding/IBondingManager.sol";
import "../../../token/IMinter.sol";
import "../../../rounds/IRoundsManager.sol";

abstract contract MContractRegistry {
    /**
     * @notice Checks if the current round has been initialized
     * @dev Executes the 'currentRoundInitialized' modifier in 'MixinContractRegistry'
     */
    modifier currentRoundInitialized() virtual {
        _;
    }

    /**
     * @dev Returns an instance of the IBondingManager interface
     */
    function bondingManager() internal view virtual returns (IBondingManager);

    /**
     * @dev Returns an instance of the IMinter interface
     */
    function minter() internal view virtual returns (IMinter);

    /**
     * @dev Returns an instance of the IRoundsManager interface
     */
    function roundsManager() internal view virtual returns (IRoundsManager);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

abstract contract MReserve {
    struct ReserveInfo {
        uint256 fundsRemaining; // Funds remaining in reserve
        uint256 claimedInCurrentRound; // Funds claimed from reserve in current round
    }

    // Emitted when funds are added to a reserve
    event ReserveFunded(address indexed reserveHolder, uint256 amount);
    // Emitted when funds are claimed from a reserve
    event ReserveClaimed(address indexed reserveHolder, address claimant, uint256 amount);

    /**
     * @notice Returns info about a reserve
     * @param _reserveHolder Address of reserve holder
     * @return info Info about the reserve for `_reserveHolder`
     */
    function getReserveInfo(address _reserveHolder) public view virtual returns (ReserveInfo memory info);

    /**
     * @notice Returns the amount of funds claimed by a claimant from a reserve
     * @param _reserveHolder Address of reserve holder
     * @param _claimant Address of claimant
     * @return Amount of funds claimed by `_claimant` from the reserve for `_reserveHolder`
     */
    function claimedReserve(address _reserveHolder, address _claimant) public view virtual returns (uint256);

    /**
     * @dev Adds funds to a reserve
     * @param _reserveHolder Address of reserve holder
     * @param _amount Amount of funds to add to reserve
     */
    function addReserve(address _reserveHolder, uint256 _amount) internal virtual;

    /**
     * @dev Clears contract storage used for a reserve
     * @param _reserveHolder Address of reserve holder
     */
    function clearReserve(address _reserveHolder) internal virtual;

    /**
     * @dev Claims funds from a reserve
     * @param _reserveHolder Address of reserve holder
     * @param _claimant Address of claimant
     * @param _amount Amount of funds to claim from the reserve
     * @return Amount of funds (<= `_amount`) claimed by `_claimant` from the reserve for `_reserveHolder`
     */
    function claimFromReserve(
        address _reserveHolder,
        address _claimant,
        uint256 _amount
    ) internal virtual returns (uint256);

    /**
     * @dev Returns the amount of funds remaining in a reserve
     * @param _reserveHolder Address of reserve holder
     * @return Amount of funds remaining in the reserve for `_reserveHolder`
     */
    function remainingReserve(address _reserveHolder) internal view virtual returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

abstract contract MTicketBrokerCore {
    struct Ticket {
        address recipient; // Address of ticket recipient
        address sender; // Address of ticket sender
        uint256 faceValue; // Face value of ticket paid to recipient if ticket wins
        uint256 winProb; // Probability ticket will win represented as winProb / (2^256 - 1)
        uint256 senderNonce; // Sender's monotonically increasing counter for each ticket
        bytes32 recipientRandHash; // keccak256 hash commitment to recipient's random value
        bytes auxData; // Auxilary data included in ticket used for additional validation
    }

    // Emitted when funds are added to a sender's deposit
    event DepositFunded(address indexed sender, uint256 amount);
    // Emitted when a winning ticket is redeemed
    event WinningTicketRedeemed(
        address indexed sender,
        address indexed recipient,
        uint256 faceValue,
        uint256 winProb,
        uint256 senderNonce,
        uint256 recipientRand,
        bytes auxData
    );
    // Emitted when a funds transfer for a winning ticket redemption is executed
    event WinningTicketTransfer(address indexed sender, address indexed recipient, uint256 amount);
    // Emitted when a sender requests an unlock
    event Unlock(address indexed sender, uint256 startRound, uint256 endRound);
    // Emitted when a sender cancels an unlock
    event UnlockCancelled(address indexed sender);
    // Emitted when a sender withdraws its deposit & reserve
    event Withdrawal(address indexed sender, uint256 deposit, uint256 reserve);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

abstract contract MTicketProcessor {
    /**
     * @dev Process sent funds.
     * @param _amount Amount of funds sent
     */
    function processFunding(uint256 _amount) internal virtual;

    /**
     * @dev Transfer withdrawal funds for a ticket sender
     * @param _amount Amount of withdrawal funds
     */
    function withdrawTransfer(address payable _sender, uint256 _amount) internal virtual;

    /**
     * @dev Transfer funds for a recipient's winning ticket
     * @param _recipient Address of recipient
     * @param _amount Amount of funds for the winning ticket
     * @param _auxData Auxilary data for the winning ticket
     */
    function winningTicketTransfer(
        address _recipient,
        uint256 _amount,
        bytes memory _auxData
    ) internal virtual;

    /**
     * @dev Validates a ticket's auxilary data (succeeds or reverts)
     * @param _auxData Auxilary data inclueded in a ticket
     */
    function requireValidTicketAuxData(bytes memory _auxData) internal view virtual;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

/**
 * @title RoundsManager interface
 */
interface IRoundsManager {
    // Events
    event NewRound(uint256 indexed round, bytes32 blockHash);

    // Deprecated events
    // These event signatures can be used to construct the appropriate topic hashes to filter for past logs corresponding
    // to these deprecated events.
    // event NewRound(uint256 round)

    // External functions
    function initializeRound() external;

    function lipUpgradeRound(uint256 _lip) external view returns (uint256);

    // Public functions
    function blockNum() external view returns (uint256);

    function blockHash(uint256 _block) external view returns (bytes32);

    function blockHashForRound(uint256 _round) external view returns (bytes32);

    function currentRound() external view returns (uint256);

    function currentRoundStartBlock() external view returns (uint256);

    function currentRoundInitialized() external view returns (bool);

    function currentRoundLocked() external view returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../IController.sol";

/**
 * @title Minter interface
 */
interface IMinter {
    // Events
    event SetCurrentRewardTokens(uint256 currentMintableTokens, uint256 currentInflation);

    // External functions
    function createReward(uint256 _fracNum, uint256 _fracDenom) external returns (uint256);

    function trustedTransferTokens(address _to, uint256 _amount) external;

    function trustedBurnTokens(uint256 _amount) external;

    function trustedWithdrawETH(address payable _to, uint256 _amount) external;

    function depositETH() external payable returns (bool);

    function setCurrentRewardTokens() external;

    function currentMintableTokens() external view returns (uint256);

    function currentMintedTokens() external view returns (uint256);

    // Public functions
    function getController() external view returns (IController);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0));
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./Ownable.sol";

/**
 * @title Pausable
 * @dev Base contract which allows children to implement an emergency stop mechanism.
 */
contract Pausable is Ownable {
    event Pause();
    event Unpause();

    bool public paused;

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     */
    modifier whenNotPaused() {
        require(!paused);
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     */
    modifier whenPaused() {
        require(paused);
        _;
    }

    /**
     * @dev called by the owner to pause, triggers stopped state
     */
    function pause() public onlyOwner whenNotPaused {
        paused = true;
        emit Pause();
    }

    /**
     * @dev called by the owner to unpause, returns to normal state
     */
    function unpause() public onlyOwner whenPaused {
        paused = false;
        emit Unpause();
    }
}