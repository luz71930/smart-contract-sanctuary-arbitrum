// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CBORChainlink} from "./vendor/CBORChainlink.sol";
import {BufferChainlink} from "./vendor/BufferChainlink.sol";

/**
 * @title Library for common Chainlink functions
 * @dev Uses imported CBOR library for encoding to buffer
 */
library Chainlink {
  uint256 internal constant defaultBufferSize = 256; // solhint-disable-line const-name-snakecase

  using CBORChainlink for BufferChainlink.buffer;

  struct Request {
    bytes32 id;
    address callbackAddress;
    bytes4 callbackFunctionId;
    uint256 nonce;
    BufferChainlink.buffer buf;
  }

  /**
   * @notice Initializes a Chainlink request
   * @dev Sets the ID, callback address, and callback function signature on the request
   * @param self The uninitialized request
   * @param jobId The Job Specification ID
   * @param callbackAddr The callback address
   * @param callbackFunc The callback function signature
   * @return The initialized request
   */
  function initialize(
    Request memory self,
    bytes32 jobId,
    address callbackAddr,
    bytes4 callbackFunc
  ) internal pure returns (Chainlink.Request memory) {
    BufferChainlink.init(self.buf, defaultBufferSize);
    self.id = jobId;
    self.callbackAddress = callbackAddr;
    self.callbackFunctionId = callbackFunc;
    return self;
  }

  /**
   * @notice Sets the data for the buffer without encoding CBOR on-chain
   * @dev CBOR can be closed with curly-brackets {} or they can be left off
   * @param self The initialized request
   * @param data The CBOR data
   */
  function setBuffer(Request memory self, bytes memory data) internal pure {
    BufferChainlink.init(self.buf, data.length);
    BufferChainlink.append(self.buf, data);
  }

  /**
   * @notice Adds a string value to the request with a given key name
   * @param self The initialized request
   * @param key The name of the key
   * @param value The string value to add
   */
  function add(
    Request memory self,
    string memory key,
    string memory value
  ) internal pure {
    self.buf.encodeString(key);
    self.buf.encodeString(value);
  }

  /**
   * @notice Adds a bytes value to the request with a given key name
   * @param self The initialized request
   * @param key The name of the key
   * @param value The bytes value to add
   */
  function addBytes(
    Request memory self,
    string memory key,
    bytes memory value
  ) internal pure {
    self.buf.encodeString(key);
    self.buf.encodeBytes(value);
  }

  /**
   * @notice Adds a int256 value to the request with a given key name
   * @param self The initialized request
   * @param key The name of the key
   * @param value The int256 value to add
   */
  function addInt(
    Request memory self,
    string memory key,
    int256 value
  ) internal pure {
    self.buf.encodeString(key);
    self.buf.encodeInt(value);
  }

  /**
   * @notice Adds a uint256 value to the request with a given key name
   * @param self The initialized request
   * @param key The name of the key
   * @param value The uint256 value to add
   */
  function addUint(
    Request memory self,
    string memory key,
    uint256 value
  ) internal pure {
    self.buf.encodeString(key);
    self.buf.encodeUInt(value);
  }

  /**
   * @notice Adds an array of strings to the request with a given key name
   * @param self The initialized request
   * @param key The name of the key
   * @param values The array of string values to add
   */
  function addStringArray(
    Request memory self,
    string memory key,
    string[] memory values
  ) internal pure {
    self.buf.encodeString(key);
    self.buf.startArray();
    for (uint256 i = 0; i < values.length; i++) {
      self.buf.encodeString(values[i]);
    }
    self.buf.endSequence();
  }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.4.19;

import {BufferChainlink} from "./BufferChainlink.sol";

library CBORChainlink {
  using BufferChainlink for BufferChainlink.buffer;

  uint8 private constant MAJOR_TYPE_INT = 0;
  uint8 private constant MAJOR_TYPE_NEGATIVE_INT = 1;
  uint8 private constant MAJOR_TYPE_BYTES = 2;
  uint8 private constant MAJOR_TYPE_STRING = 3;
  uint8 private constant MAJOR_TYPE_ARRAY = 4;
  uint8 private constant MAJOR_TYPE_MAP = 5;
  uint8 private constant MAJOR_TYPE_TAG = 6;
  uint8 private constant MAJOR_TYPE_CONTENT_FREE = 7;

  uint8 private constant TAG_TYPE_BIGNUM = 2;
  uint8 private constant TAG_TYPE_NEGATIVE_BIGNUM = 3;

  function encodeFixedNumeric(BufferChainlink.buffer memory buf, uint8 major, uint64 value) private pure {
    if(value <= 23) {
      buf.appendUint8(uint8((major << 5) | value));
    } else if (value <= 0xFF) {
      buf.appendUint8(uint8((major << 5) | 24));
      buf.appendInt(value, 1);
    } else if (value <= 0xFFFF) {
      buf.appendUint8(uint8((major << 5) | 25));
      buf.appendInt(value, 2);
    } else if (value <= 0xFFFFFFFF) {
      buf.appendUint8(uint8((major << 5) | 26));
      buf.appendInt(value, 4);
    } else {
      buf.appendUint8(uint8((major << 5) | 27));
      buf.appendInt(value, 8);
    }
  }

  function encodeIndefiniteLengthType(BufferChainlink.buffer memory buf, uint8 major) private pure {
    buf.appendUint8(uint8((major << 5) | 31));
  }

  function encodeUInt(BufferChainlink.buffer memory buf, uint value) internal pure {
    if(value > 0xFFFFFFFFFFFFFFFF) {
      encodeBigNum(buf, value);
    } else {
      encodeFixedNumeric(buf, MAJOR_TYPE_INT, uint64(value));
    }
  }

  function encodeInt(BufferChainlink.buffer memory buf, int value) internal pure {
    if(value < -0x10000000000000000) {
      encodeSignedBigNum(buf, value);
    } else if(value > 0xFFFFFFFFFFFFFFFF) {
      encodeBigNum(buf, uint(value));
    } else if(value >= 0) {
      encodeFixedNumeric(buf, MAJOR_TYPE_INT, uint64(uint256(value)));
    } else {
      encodeFixedNumeric(buf, MAJOR_TYPE_NEGATIVE_INT, uint64(uint256(-1 - value)));
    }
  }

  function encodeBytes(BufferChainlink.buffer memory buf, bytes memory value) internal pure {
    encodeFixedNumeric(buf, MAJOR_TYPE_BYTES, uint64(value.length));
    buf.append(value);
  }

  function encodeBigNum(BufferChainlink.buffer memory buf, uint value) internal pure {
    buf.appendUint8(uint8((MAJOR_TYPE_TAG << 5) | TAG_TYPE_BIGNUM));
    encodeBytes(buf, abi.encode(value));
  }

  function encodeSignedBigNum(BufferChainlink.buffer memory buf, int input) internal pure {
    buf.appendUint8(uint8((MAJOR_TYPE_TAG << 5) | TAG_TYPE_NEGATIVE_BIGNUM));
    encodeBytes(buf, abi.encode(uint256(-1 - input)));
  }

  function encodeString(BufferChainlink.buffer memory buf, string memory value) internal pure {
    encodeFixedNumeric(buf, MAJOR_TYPE_STRING, uint64(bytes(value).length));
    buf.append(bytes(value));
  }

  function startArray(BufferChainlink.buffer memory buf) internal pure {
    encodeIndefiniteLengthType(buf, MAJOR_TYPE_ARRAY);
  }

  function startMap(BufferChainlink.buffer memory buf) internal pure {
    encodeIndefiniteLengthType(buf, MAJOR_TYPE_MAP);
  }

  function endSequence(BufferChainlink.buffer memory buf) internal pure {
    encodeIndefiniteLengthType(buf, MAJOR_TYPE_CONTENT_FREE);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @dev A library for working with mutable byte buffers in Solidity.
 *
 * Byte buffers are mutable and expandable, and provide a variety of primitives
 * for writing to them. At any time you can fetch a bytes object containing the
 * current contents of the buffer. The bytes object should not be stored between
 * operations, as it may change due to resizing of the buffer.
 */
library BufferChainlink {
  /**
   * @dev Represents a mutable buffer. Buffers have a current value (buf) and
   *      a capacity. The capacity may be longer than the current value, in
   *      which case it can be extended without the need to allocate more memory.
   */
  struct buffer {
    bytes buf;
    uint256 capacity;
  }

  /**
   * @dev Initializes a buffer with an initial capacity.
   * @param buf The buffer to initialize.
   * @param capacity The number of bytes of space to allocate the buffer.
   * @return The buffer, for chaining.
   */
  function init(buffer memory buf, uint256 capacity) internal pure returns (buffer memory) {
    if (capacity % 32 != 0) {
      capacity += 32 - (capacity % 32);
    }
    // Allocate space for the buffer data
    buf.capacity = capacity;
    assembly {
      let ptr := mload(0x40)
      mstore(buf, ptr)
      mstore(ptr, 0)
      mstore(0x40, add(32, add(ptr, capacity)))
    }
    return buf;
  }

  /**
   * @dev Initializes a new buffer from an existing bytes object.
   *      Changes to the buffer may mutate the original value.
   * @param b The bytes object to initialize the buffer with.
   * @return A new buffer.
   */
  function fromBytes(bytes memory b) internal pure returns (buffer memory) {
    buffer memory buf;
    buf.buf = b;
    buf.capacity = b.length;
    return buf;
  }

  function resize(buffer memory buf, uint256 capacity) private pure {
    bytes memory oldbuf = buf.buf;
    init(buf, capacity);
    append(buf, oldbuf);
  }

  function max(uint256 a, uint256 b) private pure returns (uint256) {
    if (a > b) {
      return a;
    }
    return b;
  }

  /**
   * @dev Sets buffer length to 0.
   * @param buf The buffer to truncate.
   * @return The original buffer, for chaining..
   */
  function truncate(buffer memory buf) internal pure returns (buffer memory) {
    assembly {
      let bufptr := mload(buf)
      mstore(bufptr, 0)
    }
    return buf;
  }

  /**
   * @dev Writes a byte string to a buffer. Resizes if doing so would exceed
   *      the capacity of the buffer.
   * @param buf The buffer to append to.
   * @param off The start offset to write to.
   * @param data The data to append.
   * @param len The number of bytes to copy.
   * @return The original buffer, for chaining.
   */
  function write(
    buffer memory buf,
    uint256 off,
    bytes memory data,
    uint256 len
  ) internal pure returns (buffer memory) {
    require(len <= data.length);

    if (off + len > buf.capacity) {
      resize(buf, max(buf.capacity, len + off) * 2);
    }

    uint256 dest;
    uint256 src;
    assembly {
      // Memory address of the buffer data
      let bufptr := mload(buf)
      // Length of existing buffer data
      let buflen := mload(bufptr)
      // Start address = buffer address + offset + sizeof(buffer length)
      dest := add(add(bufptr, 32), off)
      // Update buffer length if we're extending it
      if gt(add(len, off), buflen) {
        mstore(bufptr, add(len, off))
      }
      src := add(data, 32)
    }

    // Copy word-length chunks while possible
    for (; len >= 32; len -= 32) {
      assembly {
        mstore(dest, mload(src))
      }
      dest += 32;
      src += 32;
    }

    // Copy remaining bytes
    unchecked {
      uint256 mask = (256**(32 - len)) - 1;
      assembly {
        let srcpart := and(mload(src), not(mask))
        let destpart := and(mload(dest), mask)
        mstore(dest, or(destpart, srcpart))
      }
    }

    return buf;
  }

  /**
   * @dev Appends a byte string to a buffer. Resizes if doing so would exceed
   *      the capacity of the buffer.
   * @param buf The buffer to append to.
   * @param data The data to append.
   * @param len The number of bytes to copy.
   * @return The original buffer, for chaining.
   */
  function append(
    buffer memory buf,
    bytes memory data,
    uint256 len
  ) internal pure returns (buffer memory) {
    return write(buf, buf.buf.length, data, len);
  }

  /**
   * @dev Appends a byte string to a buffer. Resizes if doing so would exceed
   *      the capacity of the buffer.
   * @param buf The buffer to append to.
   * @param data The data to append.
   * @return The original buffer, for chaining.
   */
  function append(buffer memory buf, bytes memory data) internal pure returns (buffer memory) {
    return write(buf, buf.buf.length, data, data.length);
  }

  /**
   * @dev Writes a byte to the buffer. Resizes if doing so would exceed the
   *      capacity of the buffer.
   * @param buf The buffer to append to.
   * @param off The offset to write the byte at.
   * @param data The data to append.
   * @return The original buffer, for chaining.
   */
  function writeUint8(
    buffer memory buf,
    uint256 off,
    uint8 data
  ) internal pure returns (buffer memory) {
    if (off >= buf.capacity) {
      resize(buf, buf.capacity * 2);
    }

    assembly {
      // Memory address of the buffer data
      let bufptr := mload(buf)
      // Length of existing buffer data
      let buflen := mload(bufptr)
      // Address = buffer address + sizeof(buffer length) + off
      let dest := add(add(bufptr, off), 32)
      mstore8(dest, data)
      // Update buffer length if we extended it
      if eq(off, buflen) {
        mstore(bufptr, add(buflen, 1))
      }
    }
    return buf;
  }

  /**
   * @dev Appends a byte to the buffer. Resizes if doing so would exceed the
   *      capacity of the buffer.
   * @param buf The buffer to append to.
   * @param data The data to append.
   * @return The original buffer, for chaining.
   */
  function appendUint8(buffer memory buf, uint8 data) internal pure returns (buffer memory) {
    return writeUint8(buf, buf.buf.length, data);
  }

  /**
   * @dev Writes up to 32 bytes to the buffer. Resizes if doing so would
   *      exceed the capacity of the buffer.
   * @param buf The buffer to append to.
   * @param off The offset to write at.
   * @param data The data to append.
   * @param len The number of bytes to write (left-aligned).
   * @return The original buffer, for chaining.
   */
  function write(
    buffer memory buf,
    uint256 off,
    bytes32 data,
    uint256 len
  ) private pure returns (buffer memory) {
    if (len + off > buf.capacity) {
      resize(buf, (len + off) * 2);
    }

    unchecked {
      uint256 mask = (256**len) - 1;
      // Right-align data
      data = data >> (8 * (32 - len));
      assembly {
        // Memory address of the buffer data
        let bufptr := mload(buf)
        // Address = buffer address + sizeof(buffer length) + off + len
        let dest := add(add(bufptr, off), len)
        mstore(dest, or(and(mload(dest), not(mask)), data))
        // Update buffer length if we extended it
        if gt(add(off, len), mload(bufptr)) {
          mstore(bufptr, add(off, len))
        }
      }
    }
    return buf;
  }

  /**
   * @dev Writes a bytes20 to the buffer. Resizes if doing so would exceed the
   *      capacity of the buffer.
   * @param buf The buffer to append to.
   * @param off The offset to write at.
   * @param data The data to append.
   * @return The original buffer, for chaining.
   */
  function writeBytes20(
    buffer memory buf,
    uint256 off,
    bytes20 data
  ) internal pure returns (buffer memory) {
    return write(buf, off, bytes32(data), 20);
  }

  /**
   * @dev Appends a bytes20 to the buffer. Resizes if doing so would exceed
   *      the capacity of the buffer.
   * @param buf The buffer to append to.
   * @param data The data to append.
   * @return The original buffer, for chhaining.
   */
  function appendBytes20(buffer memory buf, bytes20 data) internal pure returns (buffer memory) {
    return write(buf, buf.buf.length, bytes32(data), 20);
  }

  /**
   * @dev Appends a bytes32 to the buffer. Resizes if doing so would exceed
   *      the capacity of the buffer.
   * @param buf The buffer to append to.
   * @param data The data to append.
   * @return The original buffer, for chaining.
   */
  function appendBytes32(buffer memory buf, bytes32 data) internal pure returns (buffer memory) {
    return write(buf, buf.buf.length, data, 32);
  }

  /**
   * @dev Writes an integer to the buffer. Resizes if doing so would exceed
   *      the capacity of the buffer.
   * @param buf The buffer to append to.
   * @param off The offset to write at.
   * @param data The data to append.
   * @param len The number of bytes to write (right-aligned).
   * @return The original buffer, for chaining.
   */
  function writeInt(
    buffer memory buf,
    uint256 off,
    uint256 data,
    uint256 len
  ) private pure returns (buffer memory) {
    if (len + off > buf.capacity) {
      resize(buf, (len + off) * 2);
    }

    uint256 mask = (256**len) - 1;
    assembly {
      // Memory address of the buffer data
      let bufptr := mload(buf)
      // Address = buffer address + off + sizeof(buffer length) + len
      let dest := add(add(bufptr, off), len)
      mstore(dest, or(and(mload(dest), not(mask)), data))
      // Update buffer length if we extended it
      if gt(add(off, len), mload(bufptr)) {
        mstore(bufptr, add(off, len))
      }
    }
    return buf;
  }

  /**
   * @dev Appends a byte to the end of the buffer. Resizes if doing so would
   * exceed the capacity of the buffer.
   * @param buf The buffer to append to.
   * @param data The data to append.
   * @return The original buffer.
   */
  function appendInt(
    buffer memory buf,
    uint256 data,
    uint256 len
  ) internal pure returns (buffer memory) {
    return writeInt(buf, buf.buf.length, data, len);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../Chainlink.sol";
import "../vendor/CBORChainlink.sol";
import "../vendor/BufferChainlink.sol";

contract ChainlinkTestHelper {
  using Chainlink for Chainlink.Request;
  using CBORChainlink for BufferChainlink.buffer;

  Chainlink.Request private req;

  event RequestData(bytes payload);

  function closeEvent() public {
    emit RequestData(req.buf.buf);
  }

  function setBuffer(bytes memory data) public {
    Chainlink.Request memory r2 = req;
    r2.setBuffer(data);
    req = r2;
  }

  function add(string memory _key, string memory _value) public {
    Chainlink.Request memory r2 = req;
    r2.add(_key, _value);
    req = r2;
  }

  function addBytes(string memory _key, bytes memory _value) public {
    Chainlink.Request memory r2 = req;
    r2.addBytes(_key, _value);
    req = r2;
  }

  function addInt(string memory _key, int256 _value) public {
    Chainlink.Request memory r2 = req;
    r2.addInt(_key, _value);
    req = r2;
  }

  function addUint(string memory _key, uint256 _value) public {
    Chainlink.Request memory r2 = req;
    r2.addUint(_key, _value);
    req = r2;
  }

  // Temporarily have method receive bytes32[] memory until experimental
  // string[] memory can be invoked from truffle tests.
  function addStringArray(string memory _key, string[] memory _values) public {
    Chainlink.Request memory r2 = req;
    r2.addStringArray(_key, _values);
    req = r2;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Chainlink.sol";
import "./interfaces/ENSInterface.sol";
import "./interfaces/LinkTokenInterface.sol";
import "./interfaces/ChainlinkRequestInterface.sol";
import "./interfaces/OperatorInterface.sol";
import "./interfaces/PointerInterface.sol";
import {ENSResolver as ENSResolver_Chainlink} from "./vendor/ENSResolver.sol";

/**
 * @title The ChainlinkClient contract
 * @notice Contract writers can inherit this contract in order to create requests for the
 * Chainlink network
 */
abstract contract ChainlinkClient {
  using Chainlink for Chainlink.Request;

  uint256 internal constant LINK_DIVISIBILITY = 10**18;
  uint256 private constant AMOUNT_OVERRIDE = 0;
  address private constant SENDER_OVERRIDE = address(0);
  uint256 private constant ORACLE_ARGS_VERSION = 1;
  uint256 private constant OPERATOR_ARGS_VERSION = 2;
  bytes32 private constant ENS_TOKEN_SUBNAME = keccak256("link");
  bytes32 private constant ENS_ORACLE_SUBNAME = keccak256("oracle");
  address private constant LINK_TOKEN_POINTER = 0xC89bD4E1632D3A43CB03AAAd5262cbe4038Bc571;

  ENSInterface private s_ens;
  bytes32 private s_ensNode;
  LinkTokenInterface private s_link;
  OperatorInterface private s_oracle;
  uint256 private s_requestCount = 1;
  mapping(bytes32 => address) private s_pendingRequests;

  event ChainlinkRequested(bytes32 indexed id);
  event ChainlinkFulfilled(bytes32 indexed id);
  event ChainlinkCancelled(bytes32 indexed id);

  /**
   * @notice Creates a request that can hold additional parameters
   * @param specId The Job Specification ID that the request will be created for
   * @param callbackAddr address to operate the callback on
   * @param callbackFunctionSignature function signature to use for the callback
   * @return A Chainlink Request struct in memory
   */
  function buildChainlinkRequest(
    bytes32 specId,
    address callbackAddr,
    bytes4 callbackFunctionSignature
  ) internal pure returns (Chainlink.Request memory) {
    Chainlink.Request memory req;
    return req.initialize(specId, callbackAddr, callbackFunctionSignature);
  }

  /**
   * @notice Creates a request that can hold additional parameters
   * @param specId The Job Specification ID that the request will be created for
   * @param callbackFunctionSignature function signature to use for the callback
   * @return A Chainlink Request struct in memory
   */
  function buildOperatorRequest(bytes32 specId, bytes4 callbackFunctionSignature)
    internal
    view
    returns (Chainlink.Request memory)
  {
    Chainlink.Request memory req;
    return req.initialize(specId, address(this), callbackFunctionSignature);
  }

  /**
   * @notice Creates a Chainlink request to the stored oracle address
   * @dev Calls `chainlinkRequestTo` with the stored oracle address
   * @param req The initialized Chainlink Request
   * @param payment The amount of LINK to send for the request
   * @return requestId The request ID
   */
  function sendChainlinkRequest(Chainlink.Request memory req, uint256 payment) internal returns (bytes32) {
    return sendChainlinkRequestTo(address(s_oracle), req, payment);
  }

  /**
   * @notice Creates a Chainlink request to the specified oracle address
   * @dev Generates and stores a request ID, increments the local nonce, and uses `transferAndCall` to
   * send LINK which creates a request on the target oracle contract.
   * Emits ChainlinkRequested event.
   * @param oracleAddress The address of the oracle for the request
   * @param req The initialized Chainlink Request
   * @param payment The amount of LINK to send for the request
   * @return requestId The request ID
   */
  function sendChainlinkRequestTo(
    address oracleAddress,
    Chainlink.Request memory req,
    uint256 payment
  ) internal returns (bytes32 requestId) {
    uint256 nonce = s_requestCount;
    s_requestCount = nonce + 1;
    bytes memory encodedRequest = abi.encodeWithSelector(
      ChainlinkRequestInterface.oracleRequest.selector,
      SENDER_OVERRIDE, // Sender value - overridden by onTokenTransfer by the requesting contract's address
      AMOUNT_OVERRIDE, // Amount value - overridden by onTokenTransfer by the actual amount of LINK sent
      req.id,
      address(this),
      req.callbackFunctionId,
      nonce,
      ORACLE_ARGS_VERSION,
      req.buf.buf
    );
    return _rawRequest(oracleAddress, nonce, payment, encodedRequest);
  }

  /**
   * @notice Creates a Chainlink request to the stored oracle address
   * @dev This function supports multi-word response
   * @dev Calls `sendOperatorRequestTo` with the stored oracle address
   * @param req The initialized Chainlink Request
   * @param payment The amount of LINK to send for the request
   * @return requestId The request ID
   */
  function sendOperatorRequest(Chainlink.Request memory req, uint256 payment) internal returns (bytes32) {
    return sendOperatorRequestTo(address(s_oracle), req, payment);
  }

  /**
   * @notice Creates a Chainlink request to the specified oracle address
   * @dev This function supports multi-word response
   * @dev Generates and stores a request ID, increments the local nonce, and uses `transferAndCall` to
   * send LINK which creates a request on the target oracle contract.
   * Emits ChainlinkRequested event.
   * @param oracleAddress The address of the oracle for the request
   * @param req The initialized Chainlink Request
   * @param payment The amount of LINK to send for the request
   * @return requestId The request ID
   */
  function sendOperatorRequestTo(
    address oracleAddress,
    Chainlink.Request memory req,
    uint256 payment
  ) internal returns (bytes32 requestId) {
    uint256 nonce = s_requestCount;
    s_requestCount = nonce + 1;
    bytes memory encodedRequest = abi.encodeWithSelector(
      OperatorInterface.operatorRequest.selector,
      SENDER_OVERRIDE, // Sender value - overridden by onTokenTransfer by the requesting contract's address
      AMOUNT_OVERRIDE, // Amount value - overridden by onTokenTransfer by the actual amount of LINK sent
      req.id,
      req.callbackFunctionId,
      nonce,
      OPERATOR_ARGS_VERSION,
      req.buf.buf
    );
    return _rawRequest(oracleAddress, nonce, payment, encodedRequest);
  }

  /**
   * @notice Make a request to an oracle
   * @param oracleAddress The address of the oracle for the request
   * @param nonce used to generate the request ID
   * @param payment The amount of LINK to send for the request
   * @param encodedRequest data encoded for request type specific format
   * @return requestId The request ID
   */
  function _rawRequest(
    address oracleAddress,
    uint256 nonce,
    uint256 payment,
    bytes memory encodedRequest
  ) private returns (bytes32 requestId) {
    requestId = keccak256(abi.encodePacked(this, nonce));
    s_pendingRequests[requestId] = oracleAddress;
    emit ChainlinkRequested(requestId);
    require(s_link.transferAndCall(oracleAddress, payment, encodedRequest), "unable to transferAndCall to oracle");
  }

  /**
   * @notice Allows a request to be cancelled if it has not been fulfilled
   * @dev Requires keeping track of the expiration value emitted from the oracle contract.
   * Deletes the request from the `pendingRequests` mapping.
   * Emits ChainlinkCancelled event.
   * @param requestId The request ID
   * @param payment The amount of LINK sent for the request
   * @param callbackFunc The callback function specified for the request
   * @param expiration The time of the expiration for the request
   */
  function cancelChainlinkRequest(
    bytes32 requestId,
    uint256 payment,
    bytes4 callbackFunc,
    uint256 expiration
  ) internal {
    OperatorInterface requested = OperatorInterface(s_pendingRequests[requestId]);
    delete s_pendingRequests[requestId];
    emit ChainlinkCancelled(requestId);
    requested.cancelOracleRequest(requestId, payment, callbackFunc, expiration);
  }

  /**
   * @notice the next request count to be used in generating a nonce
   * @dev starts at 1 in order to ensure consistent gas cost
   * @return returns the next request count to be used in a nonce
   */
  function getNextRequestCount() internal view returns (uint256) {
    return s_requestCount;
  }

  /**
   * @notice Sets the stored oracle address
   * @param oracleAddress The address of the oracle contract
   */
  function setChainlinkOracle(address oracleAddress) internal {
    s_oracle = OperatorInterface(oracleAddress);
  }

  /**
   * @notice Sets the LINK token address
   * @param linkAddress The address of the LINK token contract
   */
  function setChainlinkToken(address linkAddress) internal {
    s_link = LinkTokenInterface(linkAddress);
  }

  /**
   * @notice Sets the Chainlink token address for the public
   * network as given by the Pointer contract
   */
  function setPublicChainlinkToken() internal {
    setChainlinkToken(PointerInterface(LINK_TOKEN_POINTER).getAddress());
  }

  /**
   * @notice Retrieves the stored address of the LINK token
   * @return The address of the LINK token
   */
  function chainlinkTokenAddress() internal view returns (address) {
    return address(s_link);
  }

  /**
   * @notice Retrieves the stored address of the oracle contract
   * @return The address of the oracle contract
   */
  function chainlinkOracleAddress() internal view returns (address) {
    return address(s_oracle);
  }

  /**
   * @notice Allows for a request which was created on another contract to be fulfilled
   * on this contract
   * @param oracleAddress The address of the oracle contract that will fulfill the request
   * @param requestId The request ID used for the response
   */
  function addChainlinkExternalRequest(address oracleAddress, bytes32 requestId) internal notPendingRequest(requestId) {
    s_pendingRequests[requestId] = oracleAddress;
  }

  /**
   * @notice Sets the stored oracle and LINK token contracts with the addresses resolved by ENS
   * @dev Accounts for subnodes having different resolvers
   * @param ensAddress The address of the ENS contract
   * @param node The ENS node hash
   */
  function useChainlinkWithENS(address ensAddress, bytes32 node) internal {
    s_ens = ENSInterface(ensAddress);
    s_ensNode = node;
    bytes32 linkSubnode = keccak256(abi.encodePacked(s_ensNode, ENS_TOKEN_SUBNAME));
    ENSResolver_Chainlink resolver = ENSResolver_Chainlink(s_ens.resolver(linkSubnode));
    setChainlinkToken(resolver.addr(linkSubnode));
    updateChainlinkOracleWithENS();
  }

  /**
   * @notice Sets the stored oracle contract with the address resolved by ENS
   * @dev This may be called on its own as long as `useChainlinkWithENS` has been called previously
   */
  function updateChainlinkOracleWithENS() internal {
    bytes32 oracleSubnode = keccak256(abi.encodePacked(s_ensNode, ENS_ORACLE_SUBNAME));
    ENSResolver_Chainlink resolver = ENSResolver_Chainlink(s_ens.resolver(oracleSubnode));
    setChainlinkOracle(resolver.addr(oracleSubnode));
  }

  /**
   * @notice Ensures that the fulfillment is valid for this contract
   * @dev Use if the contract developer prefers methods instead of modifiers for validation
   * @param requestId The request ID for fulfillment
   */
  function validateChainlinkCallback(bytes32 requestId)
    internal
    recordChainlinkFulfillment(requestId)
  // solhint-disable-next-line no-empty-blocks
  {

  }

  /**
   * @dev Reverts if the sender is not the oracle of the request.
   * Emits ChainlinkFulfilled event.
   * @param requestId The request ID for fulfillment
   */
  modifier recordChainlinkFulfillment(bytes32 requestId) {
    require(msg.sender == s_pendingRequests[requestId], "Source must be the oracle of the request");
    delete s_pendingRequests[requestId];
    emit ChainlinkFulfilled(requestId);
    _;
  }

  /**
   * @dev Reverts if the request is already pending
   * @param requestId The request ID for fulfillment
   */
  modifier notPendingRequest(bytes32 requestId) {
    require(s_pendingRequests[requestId] == address(0), "Request is already pending");
    _;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ENSInterface {
  // Logged when the owner of a node assigns a new owner to a subnode.
  event NewOwner(bytes32 indexed node, bytes32 indexed label, address owner);

  // Logged when the owner of a node transfers ownership to a new account.
  event Transfer(bytes32 indexed node, address owner);

  // Logged when the resolver for a node changes.
  event NewResolver(bytes32 indexed node, address resolver);

  // Logged when the TTL of a node changes
  event NewTTL(bytes32 indexed node, uint64 ttl);

  function setSubnodeOwner(
    bytes32 node,
    bytes32 label,
    address owner
  ) external;

  function setResolver(bytes32 node, address resolver) external;

  function setOwner(bytes32 node, address owner) external;

  function setTTL(bytes32 node, uint64 ttl) external;

  function owner(bytes32 node) external view returns (address);

  function resolver(bytes32 node) external view returns (address);

  function ttl(bytes32 node) external view returns (uint64);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface LinkTokenInterface {
  function allowance(address owner, address spender) external view returns (uint256 remaining);

  function approve(address spender, uint256 value) external returns (bool success);

  function balanceOf(address owner) external view returns (uint256 balance);

  function decimals() external view returns (uint8 decimalPlaces);

  function decreaseApproval(address spender, uint256 addedValue) external returns (bool success);

  function increaseApproval(address spender, uint256 subtractedValue) external;

  function name() external view returns (string memory tokenName);

  function symbol() external view returns (string memory tokenSymbol);

  function totalSupply() external view returns (uint256 totalTokensIssued);

  function transfer(address to, uint256 value) external returns (bool success);

  function transferAndCall(
    address to,
    uint256 value,
    bytes calldata data
  ) external returns (bool success);

  function transferFrom(
    address from,
    address to,
    uint256 value
  ) external returns (bool success);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ChainlinkRequestInterface {
  function oracleRequest(
    address sender,
    uint256 requestPrice,
    bytes32 serviceAgreementID,
    address callbackAddress,
    bytes4 callbackFunctionId,
    uint256 nonce,
    uint256 dataVersion,
    bytes calldata data
  ) external;

  function cancelOracleRequest(
    bytes32 requestId,
    uint256 payment,
    bytes4 callbackFunctionId,
    uint256 expiration
  ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./OracleInterface.sol";
import "./ChainlinkRequestInterface.sol";

interface OperatorInterface is OracleInterface, ChainlinkRequestInterface {
  function operatorRequest(
    address sender,
    uint256 payment,
    bytes32 specId,
    bytes4 callbackFunctionId,
    uint256 nonce,
    uint256 dataVersion,
    bytes calldata data
  ) external;

  function fulfillOracleRequest2(
    bytes32 requestId,
    uint256 payment,
    address callbackAddress,
    bytes4 callbackFunctionId,
    uint256 expiration,
    bytes calldata data
  ) external returns (bool);

  function ownerTransferAndCall(
    address to,
    uint256 value,
    bytes calldata data
  ) external returns (bool success);

  function distributeFunds(address payable[] calldata receivers, uint256[] calldata amounts) external payable;

  function getAuthorizedSenders() external returns (address[] memory);

  function setAuthorizedSenders(address[] calldata senders) external;

  function getForwarder() external returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface PointerInterface {
  function getAddress() external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract ENSResolver {
  function addr(bytes32 node) public view virtual returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface OracleInterface {
  function fulfillOracleRequest(
    bytes32 requestId,
    uint256 payment,
    address callbackAddress,
    bytes4 callbackFunctionId,
    uint256 expiration,
    bytes32 data
  ) external returns (bool);

  function isAuthorizedSender(address node) external view returns (bool);

  function withdraw(address recipient, uint256 amount) external;

  function withdrawable() external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../ChainlinkClient.sol";

contract ChainlinkClientTestHelper is ChainlinkClient {
  constructor(address _link, address _oracle) {
    setChainlinkToken(_link);
    setChainlinkOracle(_oracle);
  }

  event Request(bytes32 id, address callbackAddress, bytes4 callbackfunctionSelector, bytes data);
  event LinkAmount(uint256 amount);

  function publicNewRequest(
    bytes32 _id,
    address _address,
    bytes memory _fulfillmentSignature
  ) public {
    Chainlink.Request memory req = buildChainlinkRequest(_id, _address, bytes4(keccak256(_fulfillmentSignature)));
    emit Request(req.id, req.callbackAddress, req.callbackFunctionId, req.buf.buf);
  }

  function publicRequest(
    bytes32 _id,
    address _address,
    bytes memory _fulfillmentSignature,
    uint256 _wei
  ) public {
    Chainlink.Request memory req = buildChainlinkRequest(_id, _address, bytes4(keccak256(_fulfillmentSignature)));
    sendChainlinkRequest(req, _wei);
  }

  function publicRequestRunTo(
    address _oracle,
    bytes32 _id,
    address _address,
    bytes memory _fulfillmentSignature,
    uint256 _wei
  ) public {
    Chainlink.Request memory run = buildChainlinkRequest(_id, _address, bytes4(keccak256(_fulfillmentSignature)));
    sendChainlinkRequestTo(_oracle, run, _wei);
  }

  function publicRequestOracleData(
    bytes32 _id,
    bytes memory _fulfillmentSignature,
    uint256 _wei
  ) public {
    Chainlink.Request memory req = buildOperatorRequest(_id, bytes4(keccak256(_fulfillmentSignature)));
    sendOperatorRequest(req, _wei);
  }

  function publicRequestOracleDataFrom(
    address _oracle,
    bytes32 _id,
    bytes memory _fulfillmentSignature,
    uint256 _wei
  ) public {
    Chainlink.Request memory run = buildOperatorRequest(_id, bytes4(keccak256(_fulfillmentSignature)));
    sendOperatorRequestTo(_oracle, run, _wei);
  }

  function publicCancelRequest(
    bytes32 _requestId,
    uint256 _payment,
    bytes4 _callbackFunctionId,
    uint256 _expiration
  ) public {
    cancelChainlinkRequest(_requestId, _payment, _callbackFunctionId, _expiration);
  }

  function publicChainlinkToken() public view returns (address) {
    return chainlinkTokenAddress();
  }

  function publicFulfillChainlinkRequest(bytes32 _requestId, bytes32) public {
    fulfillRequest(_requestId, bytes32(0));
  }

  function fulfillRequest(bytes32 _requestId, bytes32) public {
    validateChainlinkCallback(_requestId);
  }

  function publicLINK(uint256 _amount) public {
    emit LinkAmount(LINK_DIVISIBILITY * _amount);
  }

  function publicOracleAddress() public view returns (address) {
    return chainlinkOracleAddress();
  }

  function publicAddExternalRequest(address _oracle, bytes32 _requestId) public {
    addChainlinkExternalRequest(_oracle, _requestId);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/LinkTokenInterface.sol";
import "../interfaces/VRFCoordinatorV2Interface.sol";
import "../VRFConsumerBaseV2.sol";

// VRFV2RevertingExample will always revert. Used for testing only, useless in prod.
contract VRFV2RevertingExample is VRFConsumerBaseV2 {
  uint256[] public s_randomWords;
  uint256 public s_requestId;
  VRFCoordinatorV2Interface COORDINATOR;
  LinkTokenInterface LINKTOKEN;
  uint64 public s_subId;
  uint256 public s_gasAvailable;

  constructor(address vrfCoordinator, address link) VRFConsumerBaseV2(vrfCoordinator) {
    COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
    LINKTOKEN = LinkTokenInterface(link);
  }

  function fulfillRandomWords(uint256, uint256[] memory) internal override {
    revert();
  }

  function testCreateSubscriptionAndFund(uint96 amount) external {
    if (s_subId == 0) {
      s_subId = COORDINATOR.createSubscription();
      COORDINATOR.addConsumer(s_subId, address(this));
    }
    // Approve the link transfer.
    LINKTOKEN.transferAndCall(address(COORDINATOR), amount, abi.encode(s_subId));
  }

  function topUpSubscription(uint96 amount) external {
    require(s_subId != 0, "sub not set");
    // Approve the link transfer.
    LINKTOKEN.transferAndCall(address(COORDINATOR), amount, abi.encode(s_subId));
  }

  function updateSubscription(address[] memory consumers) external {
    require(s_subId != 0, "subID not set");
    for (uint256 i = 0; i < consumers.length; i++) {
      COORDINATOR.addConsumer(s_subId, consumers[i]);
    }
  }

  function testRequestRandomness(
    bytes32 keyHash,
    uint64 subId,
    uint16 minReqConfs,
    uint32 callbackGasLimit,
    uint32 numWords
  ) external returns (uint256) {
    s_requestId = COORDINATOR.requestRandomWords(keyHash, subId, minReqConfs, callbackGasLimit, numWords);
    return s_requestId;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface VRFCoordinatorV2Interface {
  /**
   * @notice Get configuration relevant for making requests
   * @return minimumRequestConfirmations global min for request confirmations
   * @return maxGasLimit global max for request gas limit
   * @return s_provingKeyHashes list of registered key hashes
   */
  function getRequestConfig()
    external
    view
    returns (
      uint16,
      uint32,
      bytes32[] memory
    );

  /**
   * @notice Request a set of random words.
   * @param keyHash - Corresponds to a particular oracle job which uses
   * that key for generating the VRF proof. Different keyHash's have different gas price
   * ceilings, so you can select a specific one to bound your maximum per request cost.
   * @param subId  - The ID of the VRF subscription. Must be funded
   * with the minimum subscription balance required for the selected keyHash.
   * @param minimumRequestConfirmations - How many blocks you'd like the
   * oracle to wait before responding to the request. See SECURITY CONSIDERATIONS
   * for why you may want to request more. The acceptable range is
   * [minimumRequestBlockConfirmations, 200].
   * @param callbackGasLimit - How much gas you'd like to receive in your
   * fulfillRandomWords callback. Note that gasleft() inside fulfillRandomWords
   * may be slightly less than this amount because of gas used calling the function
   * (argument decoding etc.), so you may need to request slightly more than you expect
   * to have inside fulfillRandomWords. The acceptable range is
   * [0, maxGasLimit]
   * @param numWords - The number of uint256 random values you'd like to receive
   * in your fulfillRandomWords callback. Note these numbers are expanded in a
   * secure way by the VRFCoordinator from a single random value supplied by the oracle.
   * @return requestId - A unique identifier of the request. Can be used to match
   * a request to a response in fulfillRandomWords.
   */
  function requestRandomWords(
    bytes32 keyHash,
    uint64 subId,
    uint16 minimumRequestConfirmations,
    uint32 callbackGasLimit,
    uint32 numWords
  ) external returns (uint256 requestId);

  /**
   * @notice Create a VRF subscription.
   * @return subId - A unique subscription id.
   * @dev You can manage the consumer set dynamically with addConsumer/removeConsumer.
   * @dev Note to fund the subscription, use transferAndCall. For example
   * @dev  LINKTOKEN.transferAndCall(
   * @dev    address(COORDINATOR),
   * @dev    amount,
   * @dev    abi.encode(subId));
   */
  function createSubscription() external returns (uint64 subId);

  /**
   * @notice Get a VRF subscription.
   * @param subId - ID of the subscription
   * @return balance - LINK balance of the subscription in juels.
   * @return reqCount - number of requests for this subscription, determines fee tier.
   * @return owner - owner of the subscription.
   * @return consumers - list of consumer address which are able to use this subscription.
   */
  function getSubscription(uint64 subId)
    external
    view
    returns (
      uint96 balance,
      uint64 reqCount,
      address owner,
      address[] memory consumers
    );

  /**
   * @notice Request subscription owner transfer.
   * @param subId - ID of the subscription
   * @param newOwner - proposed new owner of the subscription
   */
  function requestSubscriptionOwnerTransfer(uint64 subId, address newOwner) external;

  /**
   * @notice Request subscription owner transfer.
   * @param subId - ID of the subscription
   * @dev will revert if original owner of subId has
   * not requested that msg.sender become the new owner.
   */
  function acceptSubscriptionOwnerTransfer(uint64 subId) external;

  /**
   * @notice Add a consumer to a VRF subscription.
   * @param subId - ID of the subscription
   * @param consumer - New consumer which can use the subscription
   */
  function addConsumer(uint64 subId, address consumer) external;

  /**
   * @notice Remove a consumer from a VRF subscription.
   * @param subId - ID of the subscription
   * @param consumer - Consumer to remove from the subscription
   */
  function removeConsumer(uint64 subId, address consumer) external;

  /**
   * @notice Cancel a subscription
   * @param subId - ID of the subscription
   * @param to - Where to send the remaining LINK to
   */
  function cancelSubscription(uint64 subId, address to) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/** ****************************************************************************
 * @notice Interface for contracts using VRF randomness
 * *****************************************************************************
 * @dev PURPOSE
 *
 * @dev Reggie the Random Oracle (not his real job) wants to provide randomness
 * @dev to Vera the verifier in such a way that Vera can be sure he's not
 * @dev making his output up to suit himself. Reggie provides Vera a public key
 * @dev to which he knows the secret key. Each time Vera provides a seed to
 * @dev Reggie, he gives back a value which is computed completely
 * @dev deterministically from the seed and the secret key.
 *
 * @dev Reggie provides a proof by which Vera can verify that the output was
 * @dev correctly computed once Reggie tells it to her, but without that proof,
 * @dev the output is indistinguishable to her from a uniform random sample
 * @dev from the output space.
 *
 * @dev The purpose of this contract is to make it easy for unrelated contracts
 * @dev to talk to Vera the verifier about the work Reggie is doing, to provide
 * @dev simple access to a verifiable source of randomness. It ensures 2 things:
 * @dev 1. The fulfillment came from the VRFCoordinator
 * @dev 2. The consumer contract implements fulfillRandomWords.
 * *****************************************************************************
 * @dev USAGE
 *
 * @dev Calling contracts must inherit from VRFConsumerBase, and can
 * @dev initialize VRFConsumerBase's attributes in their constructor as
 * @dev shown:
 *
 * @dev   contract VRFConsumer {
 * @dev     constructor(<other arguments>, address _vrfCoordinator, address _link)
 * @dev       VRFConsumerBase(_vrfCoordinator) public {
 * @dev         <initialization with other arguments goes here>
 * @dev       }
 * @dev   }
 *
 * @dev The oracle will have given you an ID for the VRF keypair they have
 * @dev committed to (let's call it keyHash). Create subscription, fund it
 * @dev and your consumer contract as a consumer of it (see VRFCoordinatorInterface
 * @dev subscription management functions).
 * @dev Call requestRandomWords(keyHash, subId, minimumRequestConfirmations,
 * @dev callbackGasLimit, numWords),
 * @dev see (VRFCoordinatorInterface for a description of the arguments).
 *
 * @dev Once the VRFCoordinator has received and validated the oracle's response
 * @dev to your request, it will call your contract's fulfillRandomWords method.
 *
 * @dev The randomness argument to fulfillRandomWords is a set of random words
 * @dev generated from your requestId and the blockHash of the request.
 *
 * @dev If your contract could have concurrent requests open, you can use the
 * @dev requestId returned from requestRandomWords to track which response is associated
 * @dev with which randomness request.
 * @dev See "SECURITY CONSIDERATIONS" for principles to keep in mind,
 * @dev if your contract could have multiple requests in flight simultaneously.
 *
 * @dev Colliding `requestId`s are cryptographically impossible as long as seeds
 * @dev differ.
 *
 * *****************************************************************************
 * @dev SECURITY CONSIDERATIONS
 *
 * @dev A method with the ability to call your fulfillRandomness method directly
 * @dev could spoof a VRF response with any random value, so it's critical that
 * @dev it cannot be directly called by anything other than this base contract
 * @dev (specifically, by the VRFConsumerBase.rawFulfillRandomness method).
 *
 * @dev For your users to trust that your contract's random behavior is free
 * @dev from malicious interference, it's best if you can write it so that all
 * @dev behaviors implied by a VRF response are executed *during* your
 * @dev fulfillRandomness method. If your contract must store the response (or
 * @dev anything derived from it) and use it later, you must ensure that any
 * @dev user-significant behavior which depends on that stored value cannot be
 * @dev manipulated by a subsequent VRF request.
 *
 * @dev Similarly, both miners and the VRF oracle itself have some influence
 * @dev over the order in which VRF responses appear on the blockchain, so if
 * @dev your contract could have multiple VRF requests in flight simultaneously,
 * @dev you must ensure that the order in which the VRF responses arrive cannot
 * @dev be used to manipulate your contract's user-significant behavior.
 *
 * @dev Since the block hash of the block which contains the requestRandomness
 * @dev call is mixed into the input to the VRF *last*, a sufficiently powerful
 * @dev miner could, in principle, fork the blockchain to evict the block
 * @dev containing the request, forcing the request to be included in a
 * @dev different block with a different hash, and therefore a different input
 * @dev to the VRF. However, such an attack would incur a substantial economic
 * @dev cost. This cost scales with the number of blocks the VRF oracle waits
 * @dev until it calls responds to a request. It is for this reason that
 * @dev that you can signal to an oracle you'd like them to wait longer before
 * @dev responding to the request (however this is not enforced in the contract
 * @dev and so remains effective only in the case of unmodified oracle software).
 */
abstract contract VRFConsumerBaseV2 {
  error OnlyCoordinatorCanFulfill(address have, address want);
  address private immutable vrfCoordinator;

  /**
   * @param _vrfCoordinator address of VRFCoordinator contract
   */
  constructor(address _vrfCoordinator) {
    vrfCoordinator = _vrfCoordinator;
  }

  /**
   * @notice fulfillRandomness handles the VRF response. Your contract must
   * @notice implement it. See "SECURITY CONSIDERATIONS" above for important
   * @notice principles to keep in mind when implementing your fulfillRandomness
   * @notice method.
   *
   * @dev VRFConsumerBaseV2 expects its subcontracts to have a method with this
   * @dev signature, and will call it once it has verified the proof
   * @dev associated with the randomness. (It is triggered via a call to
   * @dev rawFulfillRandomness, below.)
   *
   * @param requestId The Id initially returned by requestRandomness
   * @param randomWords the VRF output expanded to the requested number of words
   */
  function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal virtual;

  // rawFulfillRandomness is called by VRFCoordinator when it receives a valid VRF
  // proof. rawFulfillRandomness then calls fulfillRandomness, after validating
  // the origin of the call
  function rawFulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external {
    if (msg.sender != vrfCoordinator) {
      revert OnlyCoordinatorCanFulfill(msg.sender, vrfCoordinator);
    }
    fulfillRandomWords(requestId, randomWords);
  }
}

// SPDX-License-Identifier: MIT
// Example of a single consumer contract which owns the subscription.
pragma solidity ^0.8.0;

import "../interfaces/LinkTokenInterface.sol";
import "../interfaces/VRFCoordinatorV2Interface.sol";
import "../VRFConsumerBaseV2.sol";

contract VRFSingleConsumerExample is VRFConsumerBaseV2 {
  VRFCoordinatorV2Interface COORDINATOR;
  LinkTokenInterface LINKTOKEN;

  struct RequestConfig {
    uint64 subId;
    uint32 callbackGasLimit;
    uint16 requestConfirmations;
    uint32 numWords;
    bytes32 keyHash;
  }
  RequestConfig public s_requestConfig;
  uint256[] public s_randomWords;
  uint256 public s_requestId;
  address s_owner;

  constructor(
    address vrfCoordinator,
    address link,
    uint32 callbackGasLimit,
    uint16 requestConfirmations,
    uint32 numWords,
    bytes32 keyHash
  ) VRFConsumerBaseV2(vrfCoordinator) {
    COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
    LINKTOKEN = LinkTokenInterface(link);
    s_owner = msg.sender;
    s_requestConfig = RequestConfig({
      subId: 0, // Unset initially
      callbackGasLimit: callbackGasLimit,
      requestConfirmations: requestConfirmations,
      numWords: numWords,
      keyHash: keyHash
    });
    subscribe();
  }

  function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
    require(requestId == s_requestId, "request ID is incorrect");
    s_randomWords = randomWords;
  }

  // Assumes the subscription is funded sufficiently.
  function requestRandomWords() external onlyOwner {
    RequestConfig memory rc = s_requestConfig;
    // Will revert if subscription is not set and funded.
    s_requestId = COORDINATOR.requestRandomWords(
      rc.keyHash,
      rc.subId,
      rc.requestConfirmations,
      rc.callbackGasLimit,
      rc.numWords
    );
  }

  // Assumes this contract owns link
  // This method is analogous to VRFv1, except the amount
  // should be selected based on the keyHash (each keyHash functions like a "gas lane"
  // with different link costs).
  function fundAndRequestRandomWords(uint256 amount) external onlyOwner {
    RequestConfig memory rc = s_requestConfig;
    LINKTOKEN.transferAndCall(address(COORDINATOR), amount, abi.encode(s_requestConfig.subId));
    // Will revert if subscription is not set and funded.
    s_requestId = COORDINATOR.requestRandomWords(
      rc.keyHash,
      rc.subId,
      rc.requestConfirmations,
      rc.callbackGasLimit,
      rc.numWords
    );
  }

  // Assumes this contract owns link
  function topUpSubscription(uint256 amount) external onlyOwner {
    LINKTOKEN.transferAndCall(address(COORDINATOR), amount, abi.encode(s_requestConfig.subId));
  }

  function withdraw(uint256 amount, address to) external onlyOwner {
    LINKTOKEN.transfer(to, amount);
  }

  function unsubscribe(address to) external onlyOwner {
    // Returns funds to this address
    COORDINATOR.cancelSubscription(s_requestConfig.subId, to);
    s_requestConfig.subId = 0;
  }

  // Keep this separate in case the contract want to unsubscribe and then
  // resubscribe.
  function subscribe() public onlyOwner {
    // Create a subscription, current subId
    address[] memory consumers = new address[](1);
    consumers[0] = address(this);
    s_requestConfig.subId = COORDINATOR.createSubscription();
    COORDINATOR.addConsumer(s_requestConfig.subId, consumers[0]);
  }

  modifier onlyOwner() {
    require(msg.sender == s_owner);
    _;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/LinkTokenInterface.sol";
import "../interfaces/VRFCoordinatorV2Interface.sol";
import "../VRFConsumerBaseV2.sol";

contract VRFMaliciousConsumerV2 is VRFConsumerBaseV2 {
  uint256[] public s_randomWords;
  uint256 public s_requestId;
  VRFCoordinatorV2Interface COORDINATOR;
  LinkTokenInterface LINKTOKEN;
  uint64 public s_subId;
  uint256 public s_gasAvailable;
  bytes32 s_keyHash;

  constructor(address vrfCoordinator, address link) VRFConsumerBaseV2(vrfCoordinator) {
    COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
    LINKTOKEN = LinkTokenInterface(link);
  }

  function setKeyHash(bytes32 keyHash) public {
    s_keyHash = keyHash;
  }

  function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
    s_gasAvailable = gasleft();
    s_randomWords = randomWords;
    s_requestId = requestId;
    // Should revert
    COORDINATOR.requestRandomWords(s_keyHash, s_subId, 1, 200000, 1);
  }

  function testCreateSubscriptionAndFund(uint96 amount) external {
    if (s_subId == 0) {
      s_subId = COORDINATOR.createSubscription();
      COORDINATOR.addConsumer(s_subId, address(this));
    }
    // Approve the link transfer.
    LINKTOKEN.transferAndCall(address(COORDINATOR), amount, abi.encode(s_subId));
  }

  function updateSubscription(address[] memory consumers) external {
    require(s_subId != 0, "subID not set");
    for (uint256 i = 0; i < consumers.length; i++) {
      COORDINATOR.addConsumer(s_subId, consumers[i]);
    }
  }

  function testRequestRandomness() external returns (uint256) {
    return COORDINATOR.requestRandomWords(s_keyHash, s_subId, 1, 500000, 1);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/LinkTokenInterface.sol";
import "../interfaces/VRFCoordinatorV2Interface.sol";
import "../VRFConsumerBaseV2.sol";

contract VRFExternalSubOwnerExample is VRFConsumerBaseV2 {
  VRFCoordinatorV2Interface COORDINATOR;
  LinkTokenInterface LINKTOKEN;

  uint256[] public s_randomWords;
  uint256 public s_requestId;
  address s_owner;

  constructor(address vrfCoordinator, address link) VRFConsumerBaseV2(vrfCoordinator) {
    COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
    LINKTOKEN = LinkTokenInterface(link);
    s_owner = msg.sender;
  }

  function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
    require(requestId == s_requestId, "request ID is incorrect");
    s_randomWords = randomWords;
  }

  function requestRandomWords(
    uint64 subId,
    uint32 callbackGasLimit,
    uint16 requestConfirmations,
    uint32 numWords,
    bytes32 keyHash
  ) external onlyOwner {
    // Will revert if subscription is not funded.
    s_requestId = COORDINATOR.requestRandomWords(keyHash, subId, requestConfirmations, callbackGasLimit, numWords);
  }

  function transferOwnership(address newOwner) external onlyOwner {
    s_owner = newOwner;
  }

  modifier onlyOwner() {
    require(msg.sender == s_owner);
    _;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/LinkTokenInterface.sol";
import "../interfaces/VRFCoordinatorV2Interface.sol";
import "../VRFConsumerBaseV2.sol";

contract VRFConsumerV2 is VRFConsumerBaseV2 {
  uint256[] public s_randomWords;
  uint256 public s_requestId;
  VRFCoordinatorV2Interface COORDINATOR;
  LinkTokenInterface LINKTOKEN;
  uint64 public s_subId;
  uint256 public s_gasAvailable;

  constructor(address vrfCoordinator, address link) VRFConsumerBaseV2(vrfCoordinator) {
    COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
    LINKTOKEN = LinkTokenInterface(link);
  }

  function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
    require(requestId == s_requestId, "request ID is incorrect");

    s_gasAvailable = gasleft();
    s_randomWords = randomWords;
  }

  function testCreateSubscriptionAndFund(uint96 amount) external {
    if (s_subId == 0) {
      s_subId = COORDINATOR.createSubscription();
      COORDINATOR.addConsumer(s_subId, address(this));
    }
    // Approve the link transfer.
    LINKTOKEN.transferAndCall(address(COORDINATOR), amount, abi.encode(s_subId));
  }

  function topUpSubscription(uint96 amount) external {
    require(s_subId != 0, "sub not set");
    // Approve the link transfer.
    LINKTOKEN.transferAndCall(address(COORDINATOR), amount, abi.encode(s_subId));
  }

  function updateSubscription(address[] memory consumers) external {
    require(s_subId != 0, "subID not set");
    for (uint256 i = 0; i < consumers.length; i++) {
      COORDINATOR.addConsumer(s_subId, consumers[i]);
    }
  }

  function testRequestRandomness(
    bytes32 keyHash,
    uint64 subId,
    uint16 minReqConfs,
    uint32 callbackGasLimit,
    uint32 numWords
  ) external returns (uint256) {
    s_requestId = COORDINATOR.requestRandomWords(keyHash, subId, minReqConfs, callbackGasLimit, numWords);
    return s_requestId;
  }
}

// SPDX-License-Identifier: MIT
// A mock for testing code that relies on VRFCoordinatorV2.
pragma solidity ^0.8.0;

import "../interfaces/LinkTokenInterface.sol";
import "../interfaces/VRFCoordinatorV2Interface.sol";
import "../VRFConsumerBaseV2.sol";

contract VRFCoordinatorV2Mock is VRFCoordinatorV2Interface {
  uint96 public immutable BASE_FEE;
  uint96 public immutable GAS_PRICE_LINK;

  error InvalidSubscription();
  error InsufficientBalance();
  error MustBeSubOwner(address owner);

  event RandomWordsRequested(
    bytes32 indexed keyHash,
    uint256 requestId,
    uint256 preSeed,
    uint64 indexed subId,
    uint16 minimumRequestConfirmations,
    uint32 callbackGasLimit,
    uint32 numWords,
    address indexed sender
  );
  event RandomWordsFulfilled(uint256 indexed requestId, uint256 outputSeed, uint96 payment, bool success);
  event SubscriptionCreated(uint64 indexed subId, address owner);
  event SubscriptionFunded(uint64 indexed subId, uint256 oldBalance, uint256 newBalance);
  event SubscriptionCanceled(uint64 indexed subId, address to, uint256 amount);

  uint64 s_currentSubId;
  uint256 s_nextRequestId = 1;
  uint256 s_nextPreSeed = 100;
  struct Subscription {
    address owner;
    uint96 balance;
  }
  mapping(uint64 => Subscription) s_subscriptions; /* subId */ /* subscription */

  struct Request {
    uint64 subId;
    uint32 callbackGasLimit;
    uint32 numWords;
  }
  mapping(uint256 => Request) s_requests; /* requestId */ /* request */

  constructor(uint96 _baseFee, uint96 _gasPriceLink) {
    BASE_FEE = _baseFee;
    GAS_PRICE_LINK = _gasPriceLink;
  }

  /**
   * @notice fulfillRandomWords fulfills the given request, sending the random words to the supplied
   * @notice consumer.
   *
   * @dev This mock uses a simplified formula for calculating payment amount and gas usage, and does
   * @dev not account for all edge cases handled in the real VRF coordinator. When making requests
   * @dev against the real coordinator a small amount of additional LINK is required.
   *
   * @param _requestId the request to fulfill
   * @param _consumer the VRF randomness consumer to send the result to
   */
  function fulfillRandomWords(uint256 _requestId, address _consumer) external {
    uint256 startGas = gasleft();
    if (s_requests[_requestId].subId == 0) {
      revert("nonexistent request");
    }
    Request memory req = s_requests[_requestId];

    uint256[] memory words = new uint256[](req.numWords);
    for (uint256 i = 0; i < req.numWords; i++) {
      words[i] = uint256(keccak256(abi.encode(_requestId, i)));
    }

    VRFConsumerBaseV2 v;
    bytes memory callReq = abi.encodeWithSelector(v.rawFulfillRandomWords.selector, _requestId, words);
    (bool success, ) = _consumer.call{gas: req.callbackGasLimit}(callReq);

    uint96 payment = uint96(BASE_FEE + ((startGas - gasleft()) * GAS_PRICE_LINK));
    if (s_subscriptions[req.subId].balance < payment) {
      revert InsufficientBalance();
    }
    s_subscriptions[req.subId].balance -= payment;
    delete (s_requests[_requestId]);
    emit RandomWordsFulfilled(_requestId, _requestId, payment, success);
  }

  /**
   * @notice fundSubscription allows funding a subscription with an arbitrary amount for testing.
   *
   * @param _subId the subscription to fund
   * @param _amount the amount to fund
   */
  function fundSubscription(uint64 _subId, uint96 _amount) public {
    if (s_subscriptions[_subId].owner == address(0)) {
      revert InvalidSubscription();
    }
    uint96 oldBalance = s_subscriptions[_subId].balance;
    s_subscriptions[_subId].balance += _amount;
    emit SubscriptionFunded(_subId, oldBalance, oldBalance + _amount);
  }

  function requestRandomWords(
    bytes32 _keyHash,
    uint64 _subId,
    uint16 _minimumRequestConfirmations,
    uint32 _callbackGasLimit,
    uint32 _numWords
  ) external override returns (uint256) {
    if (s_subscriptions[_subId].owner == address(0)) {
      revert InvalidSubscription();
    }

    uint256 requestId = s_nextRequestId++;
    uint256 preSeed = s_nextPreSeed++;

    s_requests[requestId] = Request({subId: _subId, callbackGasLimit: _callbackGasLimit, numWords: _numWords});

    emit RandomWordsRequested(
      _keyHash,
      requestId,
      preSeed,
      _subId,
      _minimumRequestConfirmations,
      _callbackGasLimit,
      _numWords,
      msg.sender
    );
    return requestId;
  }

  function createSubscription() external override returns (uint64 _subId) {
    s_currentSubId++;
    s_subscriptions[s_currentSubId] = Subscription({owner: msg.sender, balance: 0});
    emit SubscriptionCreated(s_currentSubId, msg.sender);
    return s_currentSubId;
  }

  function getSubscription(uint64 _subId)
    external
    view
    override
    returns (
      uint96 balance,
      uint64 reqCount,
      address owner,
      address[] memory consumers
    )
  {
    if (s_subscriptions[_subId].owner == address(0)) {
      revert InvalidSubscription();
    }
    return (s_subscriptions[_subId].balance, 0, s_subscriptions[_subId].owner, new address[](0));
  }

  function cancelSubscription(uint64 _subId, address _to) external override onlySubOwner(_subId) {
    emit SubscriptionCanceled(_subId, _to, s_subscriptions[_subId].balance);
    delete (s_subscriptions[_subId]);
  }

  modifier onlySubOwner(uint64 _subId) {
    address owner = s_subscriptions[_subId].owner;
    if (owner == address(0)) {
      revert InvalidSubscription();
    }
    if (msg.sender != owner) {
      revert MustBeSubOwner(owner);
    }
    _;
  }

  function getRequestConfig()
    external
    pure
    override
    returns (
      uint16,
      uint32,
      bytes32[] memory
    )
  {
    return (3, 2000000, new bytes32[](0));
  }

  function addConsumer(uint64 _subId, address _consumer) external pure override {
    revert("not implemented");
  }

  function removeConsumer(uint64 _subId, address _consumer) external pure override {
    revert("not implemented");
  }

  function requestSubscriptionOwnerTransfer(uint64 _subId, address _newOwner) external pure override {
    revert("not implemented");
  }

  function acceptSubscriptionOwnerTransfer(uint64 _subId) external pure override {
    revert("not implemented");
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/LinkTokenInterface.sol";
import "../interfaces/BlockhashStoreInterface.sol";
import "../interfaces/AggregatorV3Interface.sol";
import "../interfaces/VRFCoordinatorV2Interface.sol";
import "../interfaces/TypeAndVersionInterface.sol";
import "../interfaces/ERC677ReceiverInterface.sol";
import "./VRF.sol";
import "../ConfirmedOwner.sol";
import "../VRFConsumerBaseV2.sol";

contract VRFCoordinatorV2 is
  VRF,
  ConfirmedOwner,
  TypeAndVersionInterface,
  VRFCoordinatorV2Interface,
  ERC677ReceiverInterface
{
  LinkTokenInterface public immutable LINK;
  AggregatorV3Interface public immutable LINK_ETH_FEED;
  BlockhashStoreInterface public immutable BLOCKHASH_STORE;

  // We need to maintain a list of consuming addresses.
  // This bound ensures we are able to loop over them as needed.
  // Should a user require more consumers, they can use multiple subscriptions.
  uint16 public constant MAX_CONSUMERS = 100;
  error TooManyConsumers();
  error InsufficientBalance();
  error InvalidConsumer(uint64 subId, address consumer);
  error InvalidSubscription();
  error OnlyCallableFromLink();
  error InvalidCalldata();
  error MustBeSubOwner(address owner);
  error PendingRequestExists();
  error MustBeRequestedOwner(address proposedOwner);
  error BalanceInvariantViolated(uint256 internalBalance, uint256 externalBalance); // Should never happen
  event FundsRecovered(address to, uint256 amount);
  // We use the subscription struct (1 word)
  // at fulfillment time.
  struct Subscription {
    // There are only 1e9*1e18 = 1e27 juels in existence, so the balance can fit in uint96 (2^96 ~ 7e28)
    uint96 balance; // Common link balance used for all consumer requests.
    uint64 reqCount; // For fee tiers
  }
  // We use the config for the mgmt APIs
  struct SubscriptionConfig {
    address owner; // Owner can fund/withdraw/cancel the sub.
    address requestedOwner; // For safely transferring sub ownership.
    // Maintains the list of keys in s_consumers.
    // We do this for 2 reasons:
    // 1. To be able to clean up all keys from s_consumers when canceling a subscription.
    // 2. To be able to return the list of all consumers in getSubscription.
    // Note that we need the s_consumers map to be able to directly check if a
    // consumer is valid without reading all the consumers from storage.
    address[] consumers;
  }
  // Note a nonce of 0 indicates an the consumer is not assigned to that subscription.
  mapping(address => mapping(uint64 => uint64)) /* consumer */ /* subId */ /* nonce */
    private s_consumers;
  mapping(uint64 => SubscriptionConfig) /* subId */ /* subscriptionConfig */
    private s_subscriptionConfigs;
  mapping(uint64 => Subscription) /* subId */ /* subscription */
    private s_subscriptions;
  // We make the sub count public so that its possible to
  // get all the current subscriptions via getSubscription.
  uint64 private s_currentSubId;
  // s_totalBalance tracks the total link sent to/from
  // this contract through onTokenTransfer, cancelSubscription and oracleWithdraw.
  // A discrepancy with this contract's link balance indicates someone
  // sent tokens using transfer and so we may need to use recoverFunds.
  uint96 private s_totalBalance;
  event SubscriptionCreated(uint64 indexed subId, address owner);
  event SubscriptionFunded(uint64 indexed subId, uint256 oldBalance, uint256 newBalance);
  event SubscriptionConsumerAdded(uint64 indexed subId, address consumer);
  event SubscriptionConsumerRemoved(uint64 indexed subId, address consumer);
  event SubscriptionCanceled(uint64 indexed subId, address to, uint256 amount);
  event SubscriptionOwnerTransferRequested(uint64 indexed subId, address from, address to);
  event SubscriptionOwnerTransferred(uint64 indexed subId, address from, address to);

  // Set this maximum to 200 to give us a 56 block window to fulfill
  // the request before requiring the block hash feeder.
  uint16 public constant MAX_REQUEST_CONFIRMATIONS = 200;
  uint32 public constant MAX_NUM_WORDS = 500;
  // 5k is plenty for an EXTCODESIZE call (2600) + warm CALL (100)
  // and some arithmetic operations.
  uint256 private constant GAS_FOR_CALL_EXACT_CHECK = 5_000;
  error InvalidRequestConfirmations(uint16 have, uint16 min, uint16 max);
  error GasLimitTooBig(uint32 have, uint32 want);
  error NumWordsTooBig(uint32 have, uint32 want);
  error ProvingKeyAlreadyRegistered(bytes32 keyHash);
  error NoSuchProvingKey(bytes32 keyHash);
  error InvalidLinkWeiPrice(int256 linkWei);
  error InsufficientGasForConsumer(uint256 have, uint256 want);
  error NoCorrespondingRequest();
  error IncorrectCommitment();
  error BlockhashNotInStore(uint256 blockNum);
  error PaymentTooLarge();
  error Reentrant();
  struct RequestCommitment {
    uint64 blockNum;
    uint64 subId;
    uint32 callbackGasLimit;
    uint32 numWords;
    address sender;
  }
  mapping(bytes32 => address) /* keyHash */ /* oracle */
    private s_provingKeys;
  bytes32[] private s_provingKeyHashes;
  mapping(address => uint96) /* oracle */ /* LINK balance */
    private s_withdrawableTokens;
  mapping(uint256 => bytes32) /* requestID */ /* commitment */
    private s_requestCommitments;
  event ProvingKeyRegistered(bytes32 keyHash, address indexed oracle);
  event ProvingKeyDeregistered(bytes32 keyHash, address indexed oracle);
  event RandomWordsRequested(
    bytes32 indexed keyHash,
    uint256 requestId,
    uint256 preSeed,
    uint64 indexed subId,
    uint16 minimumRequestConfirmations,
    uint32 callbackGasLimit,
    uint32 numWords,
    address indexed sender
  );
  event RandomWordsFulfilled(uint256 indexed requestId, uint256 outputSeed, uint96 payment, bool success);

  struct Config {
    uint16 minimumRequestConfirmations;
    uint32 maxGasLimit;
    // Reentrancy protection.
    bool reentrancyLock;
    // stalenessSeconds is how long before we consider the feed price to be stale
    // and fallback to fallbackWeiPerUnitLink.
    uint32 stalenessSeconds;
    // Gas to cover oracle payment after we calculate the payment.
    // We make it configurable in case those operations are repriced.
    uint32 gasAfterPaymentCalculation;
  }
  int256 private s_fallbackWeiPerUnitLink;
  Config private s_config;
  FeeConfig private s_feeConfig;
  struct FeeConfig {
    // Flat fee charged per fulfillment in millionths of link
    // So fee range is [0, 2^32/10^6].
    uint32 fulfillmentFlatFeeLinkPPMTier1;
    uint32 fulfillmentFlatFeeLinkPPMTier2;
    uint32 fulfillmentFlatFeeLinkPPMTier3;
    uint32 fulfillmentFlatFeeLinkPPMTier4;
    uint32 fulfillmentFlatFeeLinkPPMTier5;
    uint24 reqsForTier2;
    uint24 reqsForTier3;
    uint24 reqsForTier4;
    uint24 reqsForTier5;
  }
  event ConfigSet(
    uint16 minimumRequestConfirmations,
    uint32 maxGasLimit,
    uint32 stalenessSeconds,
    uint32 gasAfterPaymentCalculation,
    int256 fallbackWeiPerUnitLink,
    FeeConfig feeConfig
  );

  constructor(
    address link,
    address blockhashStore,
    address linkEthFeed
  ) ConfirmedOwner(msg.sender) {
    LINK = LinkTokenInterface(link);
    LINK_ETH_FEED = AggregatorV3Interface(linkEthFeed);
    BLOCKHASH_STORE = BlockhashStoreInterface(blockhashStore);
  }

  /**
   * @notice Registers a proving key to an oracle.
   * @param oracle address of the oracle
   * @param publicProvingKey key that oracle can use to submit vrf fulfillments
   */
  function registerProvingKey(address oracle, uint256[2] calldata publicProvingKey) external onlyOwner {
    bytes32 kh = hashOfKey(publicProvingKey);
    if (s_provingKeys[kh] != address(0)) {
      revert ProvingKeyAlreadyRegistered(kh);
    }
    s_provingKeys[kh] = oracle;
    s_provingKeyHashes.push(kh);
    emit ProvingKeyRegistered(kh, oracle);
  }

  /**
   * @notice Deregisters a proving key to an oracle.
   * @param publicProvingKey key that oracle can use to submit vrf fulfillments
   */
  function deregisterProvingKey(uint256[2] calldata publicProvingKey) external onlyOwner {
    bytes32 kh = hashOfKey(publicProvingKey);
    address oracle = s_provingKeys[kh];
    if (oracle == address(0)) {
      revert NoSuchProvingKey(kh);
    }
    delete s_provingKeys[kh];
    for (uint256 i = 0; i < s_provingKeyHashes.length; i++) {
      if (s_provingKeyHashes[i] == kh) {
        bytes32 last = s_provingKeyHashes[s_provingKeyHashes.length - 1];
        // Copy last element and overwrite kh to be deleted with it
        s_provingKeyHashes[i] = last;
        s_provingKeyHashes.pop();
      }
    }
    emit ProvingKeyDeregistered(kh, oracle);
  }

  /**
   * @notice Returns the proving key hash key associated with this public key
   * @param publicKey the key to return the hash of
   */
  function hashOfKey(uint256[2] memory publicKey) public pure returns (bytes32) {
    return keccak256(abi.encode(publicKey));
  }

  /**
   * @notice Sets the configuration of the vrfv2 coordinator
   * @param minimumRequestConfirmations global min for request confirmations
   * @param maxGasLimit global max for request gas limit
   * @param stalenessSeconds if the eth/link feed is more stale then this, use the fallback price
   * @param gasAfterPaymentCalculation gas used in doing accounting after completing the gas measurement
   * @param fallbackWeiPerUnitLink fallback eth/link price in the case of a stale feed
   * @param feeConfig fee tier configuration
   */
  function setConfig(
    uint16 minimumRequestConfirmations,
    uint32 maxGasLimit,
    uint32 stalenessSeconds,
    uint32 gasAfterPaymentCalculation,
    int256 fallbackWeiPerUnitLink,
    FeeConfig memory feeConfig
  ) external onlyOwner {
    if (minimumRequestConfirmations > MAX_REQUEST_CONFIRMATIONS) {
      revert InvalidRequestConfirmations(
        minimumRequestConfirmations,
        minimumRequestConfirmations,
        MAX_REQUEST_CONFIRMATIONS
      );
    }
    if (fallbackWeiPerUnitLink <= 0) {
      revert InvalidLinkWeiPrice(fallbackWeiPerUnitLink);
    }
    s_config = Config({
      minimumRequestConfirmations: minimumRequestConfirmations,
      maxGasLimit: maxGasLimit,
      stalenessSeconds: stalenessSeconds,
      gasAfterPaymentCalculation: gasAfterPaymentCalculation,
      reentrancyLock: false
    });
    s_feeConfig = feeConfig;
    s_fallbackWeiPerUnitLink = fallbackWeiPerUnitLink;
    emit ConfigSet(
      minimumRequestConfirmations,
      maxGasLimit,
      stalenessSeconds,
      gasAfterPaymentCalculation,
      fallbackWeiPerUnitLink,
      s_feeConfig
    );
  }

  function getConfig()
    external
    view
    returns (
      uint16 minimumRequestConfirmations,
      uint32 maxGasLimit,
      uint32 stalenessSeconds,
      uint32 gasAfterPaymentCalculation
    )
  {
    return (
      s_config.minimumRequestConfirmations,
      s_config.maxGasLimit,
      s_config.stalenessSeconds,
      s_config.gasAfterPaymentCalculation
    );
  }

  function getFeeConfig()
    external
    view
    returns (
      uint32 fulfillmentFlatFeeLinkPPMTier1,
      uint32 fulfillmentFlatFeeLinkPPMTier2,
      uint32 fulfillmentFlatFeeLinkPPMTier3,
      uint32 fulfillmentFlatFeeLinkPPMTier4,
      uint32 fulfillmentFlatFeeLinkPPMTier5,
      uint24 reqsForTier2,
      uint24 reqsForTier3,
      uint24 reqsForTier4,
      uint24 reqsForTier5
    )
  {
    return (
      s_feeConfig.fulfillmentFlatFeeLinkPPMTier1,
      s_feeConfig.fulfillmentFlatFeeLinkPPMTier2,
      s_feeConfig.fulfillmentFlatFeeLinkPPMTier3,
      s_feeConfig.fulfillmentFlatFeeLinkPPMTier4,
      s_feeConfig.fulfillmentFlatFeeLinkPPMTier5,
      s_feeConfig.reqsForTier2,
      s_feeConfig.reqsForTier3,
      s_feeConfig.reqsForTier4,
      s_feeConfig.reqsForTier5
    );
  }

  function getTotalBalance() external view returns (uint256) {
    return s_totalBalance;
  }

  function getFallbackWeiPerUnitLink() external view returns (int256) {
    return s_fallbackWeiPerUnitLink;
  }

  /**
   * @notice Owner cancel subscription, sends remaining link directly to the subscription owner.
   * @param subId subscription id
   * @dev notably can be called even if there are pending requests, outstanding ones may fail onchain
   */
  function ownerCancelSubscription(uint64 subId) external onlyOwner {
    if (s_subscriptionConfigs[subId].owner == address(0)) {
      revert InvalidSubscription();
    }
    cancelSubscriptionHelper(subId, s_subscriptionConfigs[subId].owner);
  }

  /**
   * @notice Recover link sent with transfer instead of transferAndCall.
   * @param to address to send link to
   */
  function recoverFunds(address to) external onlyOwner {
    uint256 externalBalance = LINK.balanceOf(address(this));
    uint256 internalBalance = uint256(s_totalBalance);
    if (internalBalance > externalBalance) {
      revert BalanceInvariantViolated(internalBalance, externalBalance);
    }
    if (internalBalance < externalBalance) {
      uint256 amount = externalBalance - internalBalance;
      LINK.transfer(to, amount);
      emit FundsRecovered(to, amount);
    }
    // If the balances are equal, nothing to be done.
  }

  /**
   * @inheritdoc VRFCoordinatorV2Interface
   */
  function getRequestConfig()
    external
    view
    override
    returns (
      uint16,
      uint32,
      bytes32[] memory
    )
  {
    return (s_config.minimumRequestConfirmations, s_config.maxGasLimit, s_provingKeyHashes);
  }

  /**
   * @inheritdoc VRFCoordinatorV2Interface
   */
  function requestRandomWords(
    bytes32 keyHash,
    uint64 subId,
    uint16 requestConfirmations,
    uint32 callbackGasLimit,
    uint32 numWords
  ) external override nonReentrant returns (uint256) {
    // Input validation using the subscription storage.
    if (s_subscriptionConfigs[subId].owner == address(0)) {
      revert InvalidSubscription();
    }
    // Its important to ensure that the consumer is in fact who they say they
    // are, otherwise they could use someone else's subscription balance.
    // A nonce of 0 indicates consumer is not allocated to the sub.
    uint64 currentNonce = s_consumers[msg.sender][subId];
    if (currentNonce == 0) {
      revert InvalidConsumer(subId, msg.sender);
    }
    // Input validation using the config storage word.
    if (
      requestConfirmations < s_config.minimumRequestConfirmations || requestConfirmations > MAX_REQUEST_CONFIRMATIONS
    ) {
      revert InvalidRequestConfirmations(
        requestConfirmations,
        s_config.minimumRequestConfirmations,
        MAX_REQUEST_CONFIRMATIONS
      );
    }
    // No lower bound on the requested gas limit. A user could request 0
    // and they would simply be billed for the proof verification and wouldn't be
    // able to do anything with the random value.
    if (callbackGasLimit > s_config.maxGasLimit) {
      revert GasLimitTooBig(callbackGasLimit, s_config.maxGasLimit);
    }
    if (numWords > MAX_NUM_WORDS) {
      revert NumWordsTooBig(numWords, MAX_NUM_WORDS);
    }
    // Note we do not check whether the keyHash is valid to save gas.
    // The consequence for users is that they can send requests
    // for invalid keyHashes which will simply not be fulfilled.
    uint64 nonce = currentNonce + 1;
    (uint256 requestId, uint256 preSeed) = computeRequestId(keyHash, msg.sender, subId, nonce);

    s_requestCommitments[requestId] = keccak256(
      abi.encode(requestId, block.number, subId, callbackGasLimit, numWords, msg.sender)
    );
    emit RandomWordsRequested(
      keyHash,
      requestId,
      preSeed,
      subId,
      requestConfirmations,
      callbackGasLimit,
      numWords,
      msg.sender
    );
    s_consumers[msg.sender][subId] = nonce;

    return requestId;
  }

  /**
   * @notice Get request commitment
   * @param requestId id of request
   * @dev used to determine if a request is fulfilled or not
   */
  function getCommitment(uint256 requestId) external view returns (bytes32) {
    return s_requestCommitments[requestId];
  }

  function computeRequestId(
    bytes32 keyHash,
    address sender,
    uint64 subId,
    uint64 nonce
  ) private pure returns (uint256, uint256) {
    uint256 preSeed = uint256(keccak256(abi.encode(keyHash, sender, subId, nonce)));
    return (uint256(keccak256(abi.encode(keyHash, preSeed))), preSeed);
  }

  /**
   * @dev calls target address with exactly gasAmount gas and data as calldata
   * or reverts if at least gasAmount gas is not available.
   */
  function callWithExactGas(
    uint256 gasAmount,
    address target,
    bytes memory data
  ) private returns (bool success) {
    // solhint-disable-next-line no-inline-assembly
    assembly {
      let g := gas()
      // Compute g -= GAS_FOR_CALL_EXACT_CHECK and check for underflow
      // The gas actually passed to the callee is min(gasAmount, 63//64*gas available).
      // We want to ensure that we revert if gasAmount >  63//64*gas available
      // as we do not want to provide them with less, however that check itself costs
      // gas.  GAS_FOR_CALL_EXACT_CHECK ensures we have at least enough gas to be able
      // to revert if gasAmount >  63//64*gas available.
      if lt(g, GAS_FOR_CALL_EXACT_CHECK) {
        revert(0, 0)
      }
      g := sub(g, GAS_FOR_CALL_EXACT_CHECK)
      // if g - g//64 <= gasAmount, revert
      // (we subtract g//64 because of EIP-150)
      if iszero(gt(sub(g, div(g, 64)), gasAmount)) {
        revert(0, 0)
      }
      // solidity calls check that a contract actually exists at the destination, so we do the same
      if iszero(extcodesize(target)) {
        revert(0, 0)
      }
      // call and return whether we succeeded. ignore return data
      // call(gas,addr,value,argsOffset,argsLength,retOffset,retLength)
      success := call(gasAmount, target, 0, add(data, 0x20), mload(data), 0, 0)
    }
    return success;
  }

  function getRandomnessFromProof(Proof memory proof, RequestCommitment memory rc)
    private
    view
    returns (
      bytes32 keyHash,
      uint256 requestId,
      uint256 randomness
    )
  {
    keyHash = hashOfKey(proof.pk);
    // Only registered proving keys are permitted.
    address oracle = s_provingKeys[keyHash];
    if (oracle == address(0)) {
      revert NoSuchProvingKey(keyHash);
    }
    requestId = uint256(keccak256(abi.encode(keyHash, proof.seed)));
    bytes32 commitment = s_requestCommitments[requestId];
    if (commitment == 0) {
      revert NoCorrespondingRequest();
    }
    if (
      commitment != keccak256(abi.encode(requestId, rc.blockNum, rc.subId, rc.callbackGasLimit, rc.numWords, rc.sender))
    ) {
      revert IncorrectCommitment();
    }

    bytes32 blockHash = blockhash(rc.blockNum);
    if (blockHash == bytes32(0)) {
      blockHash = BLOCKHASH_STORE.getBlockhash(rc.blockNum);
      if (blockHash == bytes32(0)) {
        revert BlockhashNotInStore(rc.blockNum);
      }
    }

    // The seed actually used by the VRF machinery, mixing in the blockhash
    uint256 actualSeed = uint256(keccak256(abi.encodePacked(proof.seed, blockHash)));
    randomness = VRF.randomValueFromVRFProof(proof, actualSeed); // Reverts on failure
  }

  /*
   * @notice Compute fee based on the request count
   * @param reqCount number of requests
   * @return feePPM fee in LINK PPM
   */
  function getFeeTier(uint64 reqCount) public view returns (uint32) {
    FeeConfig memory fc = s_feeConfig;
    if (0 <= reqCount && reqCount <= fc.reqsForTier2) {
      return fc.fulfillmentFlatFeeLinkPPMTier1;
    }
    if (fc.reqsForTier2 < reqCount && reqCount <= fc.reqsForTier3) {
      return fc.fulfillmentFlatFeeLinkPPMTier2;
    }
    if (fc.reqsForTier3 < reqCount && reqCount <= fc.reqsForTier4) {
      return fc.fulfillmentFlatFeeLinkPPMTier3;
    }
    if (fc.reqsForTier4 < reqCount && reqCount <= fc.reqsForTier5) {
      return fc.fulfillmentFlatFeeLinkPPMTier4;
    }
    return fc.fulfillmentFlatFeeLinkPPMTier5;
  }

  /*
   * @notice Fulfill a randomness request
   * @param proof contains the proof and randomness
   * @param rc request commitment pre-image, committed to at request time
   * @return payment amount billed to the subscription
   * @dev simulated offchain to determine if sufficient balance is present to fulfill the request
   */
  function fulfillRandomWords(Proof memory proof, RequestCommitment memory rc) external nonReentrant returns (uint96) {
    uint256 startGas = gasleft();
    (bytes32 keyHash, uint256 requestId, uint256 randomness) = getRandomnessFromProof(proof, rc);

    uint256[] memory randomWords = new uint256[](rc.numWords);
    for (uint256 i = 0; i < rc.numWords; i++) {
      randomWords[i] = uint256(keccak256(abi.encode(randomness, i)));
    }

    delete s_requestCommitments[requestId];
    VRFConsumerBaseV2 v;
    bytes memory resp = abi.encodeWithSelector(v.rawFulfillRandomWords.selector, requestId, randomWords);
    // Call with explicitly the amount of callback gas requested
    // Important to not let them exhaust the gas budget and avoid oracle payment.
    // Do not allow any non-view/non-pure coordinator functions to be called
    // during the consumers callback code via reentrancyLock.
    // Note that callWithExactGas will revert if we do not have sufficient gas
    // to give the callee their requested amount.
    s_config.reentrancyLock = true;
    bool success = callWithExactGas(rc.callbackGasLimit, rc.sender, resp);
    s_config.reentrancyLock = false;

    // Increment the req count for fee tier selection.
    uint64 reqCount = s_subscriptions[rc.subId].reqCount;
    s_subscriptions[rc.subId].reqCount += 1;

    // We want to charge users exactly for how much gas they use in their callback.
    // The gasAfterPaymentCalculation is meant to cover these additional operations where we
    // decrement the subscription balance and increment the oracles withdrawable balance.
    // We also add the flat link fee to the payment amount.
    // Its specified in millionths of link, if s_config.fulfillmentFlatFeeLinkPPM = 1
    // 1 link / 1e6 = 1e18 juels / 1e6 = 1e12 juels.
    uint96 payment = calculatePaymentAmount(
      startGas,
      s_config.gasAfterPaymentCalculation,
      getFeeTier(reqCount),
      tx.gasprice
    );
    if (s_subscriptions[rc.subId].balance < payment) {
      revert InsufficientBalance();
    }
    s_subscriptions[rc.subId].balance -= payment;
    s_withdrawableTokens[s_provingKeys[keyHash]] += payment;
    // Include payment in the event for tracking costs.
    emit RandomWordsFulfilled(requestId, randomness, payment, success);
    return payment;
  }

  // Get the amount of gas used for fulfillment
  function calculatePaymentAmount(
    uint256 startGas,
    uint256 gasAfterPaymentCalculation,
    uint32 fulfillmentFlatFeeLinkPPM,
    uint256 weiPerUnitGas
  ) internal view returns (uint96) {
    int256 weiPerUnitLink;
    weiPerUnitLink = getFeedData();
    if (weiPerUnitLink <= 0) {
      revert InvalidLinkWeiPrice(weiPerUnitLink);
    }
    // (1e18 juels/link) (wei/gas * gas) / (wei/link) = juels
    uint256 paymentNoFee = (1e18 * weiPerUnitGas * (gasAfterPaymentCalculation + startGas - gasleft())) /
      uint256(weiPerUnitLink);
    uint256 fee = 1e12 * uint256(fulfillmentFlatFeeLinkPPM);
    if (paymentNoFee > (1e27 - fee)) {
      revert PaymentTooLarge(); // Payment + fee cannot be more than all of the link in existence.
    }
    return uint96(paymentNoFee + fee);
  }

  function getFeedData() private view returns (int256) {
    uint32 stalenessSeconds = s_config.stalenessSeconds;
    bool staleFallback = stalenessSeconds > 0;
    uint256 timestamp;
    int256 weiPerUnitLink;
    (, weiPerUnitLink, , timestamp, ) = LINK_ETH_FEED.latestRoundData();
    // solhint-disable-next-line not-rely-on-time
    if (staleFallback && stalenessSeconds < block.timestamp - timestamp) {
      weiPerUnitLink = s_fallbackWeiPerUnitLink;
    }
    return weiPerUnitLink;
  }

  /*
   * @notice Oracle withdraw LINK earned through fulfilling requests
   * @param recipient where to send the funds
   * @param amount amount to withdraw
   */
  function oracleWithdraw(address recipient, uint96 amount) external nonReentrant {
    if (s_withdrawableTokens[msg.sender] < amount) {
      revert InsufficientBalance();
    }
    s_withdrawableTokens[msg.sender] -= amount;
    s_totalBalance -= amount;
    if (!LINK.transfer(recipient, amount)) {
      revert InsufficientBalance();
    }
  }

  function onTokenTransfer(
    address, /* sender */
    uint256 amount,
    bytes calldata data
  ) external override nonReentrant {
    if (msg.sender != address(LINK)) {
      revert OnlyCallableFromLink();
    }
    if (data.length != 32) {
      revert InvalidCalldata();
    }
    uint64 subId = abi.decode(data, (uint64));
    if (s_subscriptionConfigs[subId].owner == address(0)) {
      revert InvalidSubscription();
    }
    // We do not check that the msg.sender is the subscription owner,
    // anyone can fund a subscription.
    uint256 oldBalance = s_subscriptions[subId].balance;
    s_subscriptions[subId].balance += uint96(amount);
    s_totalBalance += uint96(amount);
    emit SubscriptionFunded(subId, oldBalance, oldBalance + amount);
  }

  function getCurrentSubId() external view returns (uint64) {
    return s_currentSubId;
  }

  /**
   * @inheritdoc VRFCoordinatorV2Interface
   */
  function getSubscription(uint64 subId)
    external
    view
    override
    returns (
      uint96 balance,
      uint64 reqCount,
      address owner,
      address[] memory consumers
    )
  {
    if (s_subscriptionConfigs[subId].owner == address(0)) {
      revert InvalidSubscription();
    }
    return (
      s_subscriptions[subId].balance,
      s_subscriptions[subId].reqCount,
      s_subscriptionConfigs[subId].owner,
      s_subscriptionConfigs[subId].consumers
    );
  }

  /**
   * @inheritdoc VRFCoordinatorV2Interface
   */
  function createSubscription() external override nonReentrant returns (uint64) {
    s_currentSubId++;
    uint64 currentSubId = s_currentSubId;
    address[] memory consumers = new address[](0);
    s_subscriptions[currentSubId] = Subscription({balance: 0, reqCount: 0});
    s_subscriptionConfigs[currentSubId] = SubscriptionConfig({
      owner: msg.sender,
      requestedOwner: address(0),
      consumers: consumers
    });

    emit SubscriptionCreated(currentSubId, msg.sender);
    return currentSubId;
  }

  /**
   * @inheritdoc VRFCoordinatorV2Interface
   */
  function requestSubscriptionOwnerTransfer(uint64 subId, address newOwner)
    external
    override
    onlySubOwner(subId)
    nonReentrant
  {
    // Proposing to address(0) would never be claimable so don't need to check.
    if (s_subscriptionConfigs[subId].requestedOwner != newOwner) {
      s_subscriptionConfigs[subId].requestedOwner = newOwner;
      emit SubscriptionOwnerTransferRequested(subId, msg.sender, newOwner);
    }
  }

  /**
   * @inheritdoc VRFCoordinatorV2Interface
   */
  function acceptSubscriptionOwnerTransfer(uint64 subId) external override nonReentrant {
    if (s_subscriptionConfigs[subId].owner == address(0)) {
      revert InvalidSubscription();
    }
    if (s_subscriptionConfigs[subId].requestedOwner != msg.sender) {
      revert MustBeRequestedOwner(s_subscriptionConfigs[subId].requestedOwner);
    }
    address oldOwner = s_subscriptionConfigs[subId].owner;
    s_subscriptionConfigs[subId].owner = msg.sender;
    s_subscriptionConfigs[subId].requestedOwner = address(0);
    emit SubscriptionOwnerTransferred(subId, oldOwner, msg.sender);
  }

  /**
   * @inheritdoc VRFCoordinatorV2Interface
   */
  function removeConsumer(uint64 subId, address consumer) external override onlySubOwner(subId) nonReentrant {
    if (s_consumers[consumer][subId] == 0) {
      revert InvalidConsumer(subId, consumer);
    }
    // Note bounded by MAX_CONSUMERS
    address[] memory consumers = s_subscriptionConfigs[subId].consumers;
    uint256 lastConsumerIndex = consumers.length - 1;
    for (uint256 i = 0; i < consumers.length; i++) {
      if (consumers[i] == consumer) {
        address last = consumers[lastConsumerIndex];
        // Storage write to preserve last element
        s_subscriptionConfigs[subId].consumers[i] = last;
        // Storage remove last element
        s_subscriptionConfigs[subId].consumers.pop();
        break;
      }
    }
    delete s_consumers[consumer][subId];
    emit SubscriptionConsumerRemoved(subId, consumer);
  }

  /**
   * @inheritdoc VRFCoordinatorV2Interface
   */
  function addConsumer(uint64 subId, address consumer) external override onlySubOwner(subId) nonReentrant {
    // Already maxed, cannot add any more consumers.
    if (s_subscriptionConfigs[subId].consumers.length == MAX_CONSUMERS) {
      revert TooManyConsumers();
    }
    if (s_consumers[consumer][subId] != 0) {
      // Idempotence - do nothing if already added.
      // Ensures uniqueness in s_subscriptions[subId].consumers.
      return;
    }
    // Initialize the nonce to 1, indicating the consumer is allocated.
    s_consumers[consumer][subId] = 1;
    s_subscriptionConfigs[subId].consumers.push(consumer);

    emit SubscriptionConsumerAdded(subId, consumer);
  }

  /**
   * @inheritdoc VRFCoordinatorV2Interface
   */
  function cancelSubscription(uint64 subId, address to) external override onlySubOwner(subId) nonReentrant {
    if (pendingRequestExists(subId)) {
      revert PendingRequestExists();
    }
    cancelSubscriptionHelper(subId, to);
  }

  function cancelSubscriptionHelper(uint64 subId, address to) private nonReentrant {
    SubscriptionConfig memory subConfig = s_subscriptionConfigs[subId];
    Subscription memory sub = s_subscriptions[subId];
    uint96 balance = sub.balance;
    // Note bounded by MAX_CONSUMERS;
    // If no consumers, does nothing.
    for (uint256 i = 0; i < subConfig.consumers.length; i++) {
      delete s_consumers[subConfig.consumers[i]][subId];
    }
    delete s_subscriptionConfigs[subId];
    delete s_subscriptions[subId];
    s_totalBalance -= balance;
    if (!LINK.transfer(to, uint256(balance))) {
      revert InsufficientBalance();
    }
    emit SubscriptionCanceled(subId, to, balance);
  }

  /*
   * @noticeCheck to see if there exists a request commitment consumers
   * for all consumers and keyhashes for a given sub.
   * @param subId where to send the funds
   * @return exits true if outstanding requests
   * @dev Looping is bounded to MAX_CONSUMERS*(number of keyhashes).
   * @dev Used to disable subscription canceling while outstanding request are present.
   */
  function pendingRequestExists(uint64 subId) public view returns (bool) {
    SubscriptionConfig memory subConfig = s_subscriptionConfigs[subId];
    for (uint256 i = 0; i < subConfig.consumers.length; i++) {
      for (uint256 j = 0; j < s_provingKeyHashes.length; j++) {
        (uint256 reqId, ) = computeRequestId(
          s_provingKeyHashes[j],
          subConfig.consumers[i],
          subId,
          s_consumers[subConfig.consumers[i]][subId]
        );
        if (s_requestCommitments[reqId] != 0) {
          return true;
        }
      }
    }
    return false;
  }

  modifier onlySubOwner(uint64 subId) {
    address owner = s_subscriptionConfigs[subId].owner;
    if (owner == address(0)) {
      revert InvalidSubscription();
    }
    if (msg.sender != owner) {
      revert MustBeSubOwner(owner);
    }
    _;
  }

  modifier nonReentrant() {
    if (s_config.reentrancyLock) {
      revert Reentrant();
    }
    _;
  }

  /**
   * @notice The type and version of this contract
   * @return Type and version string
   */
  function typeAndVersion() external pure virtual override returns (string memory) {
    return "VRFCoordinatorV2 1.0.0";
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface BlockhashStoreInterface {
  function getBlockhash(uint256 number) external view returns (bytes32);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface AggregatorV3Interface {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function version() external view returns (uint256);

  // getRoundData and latestRoundData should both raise "No data present"
  // if they do not have data to report, instead of returning unset values
  // which could be misinterpreted as actual reported values.
  function getRoundData(uint80 _roundId)
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract TypeAndVersionInterface {
  function typeAndVersion() external pure virtual returns (string memory);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface ERC677ReceiverInterface {
  function onTokenTransfer(
    address sender,
    uint256 amount,
    bytes calldata data
  ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/** ****************************************************************************
  * @notice Verification of verifiable-random-function (VRF) proofs, following
  * @notice https://datatracker.ietf.org/doc/html/draft-irtf-cfrg-vrf-05#section-5.3
  * @notice See https://eprint.iacr.org/2017/099.pdf for security proofs.

  * @dev Bibliographic references:

  * @dev Goldberg, et al., "Verifiable Random Functions (VRFs)", Internet Draft
  * @dev draft-irtf-cfrg-vrf-05, IETF, Aug 11 2019,
  * @dev https://datatracker.ietf.org/doc/html/draft-irtf-cfrg-vrf-05

  * @dev Papadopoulos, et al., "Making NSEC5 Practical for DNSSEC", Cryptology
  * @dev ePrint Archive, Report 2017/099, https://eprint.iacr.org/2017/099.pdf
  * ****************************************************************************
  * @dev USAGE

  * @dev The main entry point is randomValueFromVRFProof. See its docstring.
  * ****************************************************************************
  * @dev PURPOSE

  * @dev Reggie the Random Oracle (not his real job) wants to provide randomness
  * @dev to Vera the verifier in such a way that Vera can be sure he's not
  * @dev making his output up to suit himself. Reggie provides Vera a public key
  * @dev to which he knows the secret key. Each time Vera provides a seed to
  * @dev Reggie, he gives back a value which is computed completely
  * @dev deterministically from the seed and the secret key.

  * @dev Reggie provides a proof by which Vera can verify that the output was
  * @dev correctly computed once Reggie tells it to her, but without that proof,
  * @dev the output is computationally indistinguishable to her from a uniform
  * @dev random sample from the output space.

  * @dev The purpose of this contract is to perform that verification.
  * ****************************************************************************
  * @dev DESIGN NOTES

  * @dev The VRF algorithm verified here satisfies the full uniqueness, full
  * @dev collision resistance, and full pseudo-randomness security properties.
  * @dev See "SECURITY PROPERTIES" below, and
  * @dev https://datatracker.ietf.org/doc/html/draft-irtf-cfrg-vrf-05#section-3

  * @dev An elliptic curve point is generally represented in the solidity code
  * @dev as a uint256[2], corresponding to its affine coordinates in
  * @dev GF(FIELD_SIZE).

  * @dev For the sake of efficiency, this implementation deviates from the spec
  * @dev in some minor ways:

  * @dev - Keccak hash rather than the SHA256 hash recommended in
  * @dev   https://datatracker.ietf.org/doc/html/draft-irtf-cfrg-vrf-05#section-5.5
  * @dev   Keccak costs much less gas on the EVM, and provides similar security.

  * @dev - Secp256k1 curve instead of the P-256 or ED25519 curves recommended in
  * @dev   https://datatracker.ietf.org/doc/html/draft-irtf-cfrg-vrf-05#section-5.5
  * @dev   For curve-point multiplication, it's much cheaper to abuse ECRECOVER

  * @dev - hashToCurve recursively hashes until it finds a curve x-ordinate. On
  * @dev   the EVM, this is slightly more efficient than the recommendation in
  * @dev   https://datatracker.ietf.org/doc/html/draft-irtf-cfrg-vrf-05#section-5.4.1.1
  * @dev   step 5, to concatenate with a nonce then hash, and rehash with the
  * @dev   nonce updated until a valid x-ordinate is found.

  * @dev - hashToCurve does not include a cipher version string or the byte 0x1
  * @dev   in the hash message, as recommended in step 5.B of the draft
  * @dev   standard. They are unnecessary here because no variation in the
  * @dev   cipher suite is allowed.

  * @dev - Similarly, the hash input in scalarFromCurvePoints does not include a
  * @dev   commitment to the cipher suite, either, which differs from step 2 of
  * @dev   https://datatracker.ietf.org/doc/html/draft-irtf-cfrg-vrf-05#section-5.4.3
  * @dev   . Also, the hash input is the concatenation of the uncompressed
  * @dev   points, not the compressed points as recommended in step 3.

  * @dev - In the calculation of the challenge value "c", the "u" value (i.e.
  * @dev   the value computed by Reggie as the nonce times the secp256k1
  * @dev   generator point, see steps 5 and 7 of
  * @dev   https://datatracker.ietf.org/doc/html/draft-irtf-cfrg-vrf-05#section-5.3
  * @dev   ) is replaced by its ethereum address, i.e. the lower 160 bits of the
  * @dev   keccak hash of the original u. This is because we only verify the
  * @dev   calculation of u up to its address, by abusing ECRECOVER.
  * ****************************************************************************
  * @dev   SECURITY PROPERTIES

  * @dev Here are the security properties for this VRF:

  * @dev Full uniqueness: For any seed and valid VRF public key, there is
  * @dev   exactly one VRF output which can be proved to come from that seed, in
  * @dev   the sense that the proof will pass verifyVRFProof.

  * @dev Full collision resistance: It's cryptographically infeasible to find
  * @dev   two seeds with same VRF output from a fixed, valid VRF key

  * @dev Full pseudorandomness: Absent the proofs that the VRF outputs are
  * @dev   derived from a given seed, the outputs are computationally
  * @dev   indistinguishable from randomness.

  * @dev https://eprint.iacr.org/2017/099.pdf, Appendix B contains the proofs
  * @dev for these properties.

  * @dev For secp256k1, the key validation described in section
  * @dev https://datatracker.ietf.org/doc/html/draft-irtf-cfrg-vrf-05#section-5.6
  * @dev is unnecessary, because secp256k1 has cofactor 1, and the
  * @dev representation of the public key used here (affine x- and y-ordinates
  * @dev of the secp256k1 point on the standard y^2=x^3+7 curve) cannot refer to
  * @dev the point at infinity.
  * ****************************************************************************
  * @dev OTHER SECURITY CONSIDERATIONS
  *
  * @dev The seed input to the VRF could in principle force an arbitrary amount
  * @dev of work in hashToCurve, by requiring extra rounds of hashing and
  * @dev checking whether that's yielded the x ordinate of a secp256k1 point.
  * @dev However, under the Random Oracle Model the probability of choosing a
  * @dev point which forces n extra rounds in hashToCurve is 2⁻ⁿ. The base cost
  * @dev for calling hashToCurve is about 25,000 gas, and each round of checking
  * @dev for a valid x ordinate costs about 15,555 gas, so to find a seed for
  * @dev which hashToCurve would cost more than 2,017,000 gas, one would have to
  * @dev try, in expectation, about 2¹²⁸ seeds, which is infeasible for any
  * @dev foreseeable computational resources. (25,000 + 128 * 15,555 < 2,017,000.)

  * @dev Since the gas block limit for the Ethereum main net is 10,000,000 gas,
  * @dev this means it is infeasible for an adversary to prevent correct
  * @dev operation of this contract by choosing an adverse seed.

  * @dev (See TestMeasureHashToCurveGasCost for verification of the gas cost for
  * @dev hashToCurve.)

  * @dev It may be possible to make a secure constant-time hashToCurve function.
  * @dev See notes in hashToCurve docstring.
*/
contract VRF {
  // See https://www.secg.org/sec2-v2.pdf, section 2.4.1, for these constants.
  // Number of points in Secp256k1
  uint256 private constant GROUP_ORDER = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;
  // Prime characteristic of the galois field over which Secp256k1 is defined
  uint256 private constant FIELD_SIZE =
    // solium-disable-next-line indentation
    0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;
  uint256 private constant WORD_LENGTH_BYTES = 0x20;

  // (base^exponent) % FIELD_SIZE
  // Cribbed from https://medium.com/@rbkhmrcr/precompiles-solidity-e5d29bd428c4
  function bigModExp(uint256 base, uint256 exponent) internal view returns (uint256 exponentiation) {
    uint256 callResult;
    uint256[6] memory bigModExpContractInputs;
    bigModExpContractInputs[0] = WORD_LENGTH_BYTES; // Length of base
    bigModExpContractInputs[1] = WORD_LENGTH_BYTES; // Length of exponent
    bigModExpContractInputs[2] = WORD_LENGTH_BYTES; // Length of modulus
    bigModExpContractInputs[3] = base;
    bigModExpContractInputs[4] = exponent;
    bigModExpContractInputs[5] = FIELD_SIZE;
    uint256[1] memory output;
    assembly {
      // solhint-disable-line no-inline-assembly
      callResult := staticcall(
        not(0), // Gas cost: no limit
        0x05, // Bigmodexp contract address
        bigModExpContractInputs,
        0xc0, // Length of input segment: 6*0x20-bytes
        output,
        0x20 // Length of output segment
      )
    }
    if (callResult == 0) {
      revert("bigModExp failure!");
    }
    return output[0];
  }

  // Let q=FIELD_SIZE. q % 4 = 3, ∴ x≡r^2 mod q ⇒ x^SQRT_POWER≡±r mod q.  See
  // https://en.wikipedia.org/wiki/Modular_square_root#Prime_or_prime_power_modulus
  uint256 private constant SQRT_POWER = (FIELD_SIZE + 1) >> 2;

  // Computes a s.t. a^2 = x in the field. Assumes a exists
  function squareRoot(uint256 x) internal view returns (uint256) {
    return bigModExp(x, SQRT_POWER);
  }

  // The value of y^2 given that (x,y) is on secp256k1.
  function ySquared(uint256 x) internal pure returns (uint256) {
    // Curve is y^2=x^3+7. See section 2.4.1 of https://www.secg.org/sec2-v2.pdf
    uint256 xCubed = mulmod(x, mulmod(x, x, FIELD_SIZE), FIELD_SIZE);
    return addmod(xCubed, 7, FIELD_SIZE);
  }

  // True iff p is on secp256k1
  function isOnCurve(uint256[2] memory p) internal pure returns (bool) {
    // Section 2.3.6. in https://www.secg.org/sec1-v2.pdf
    // requires each ordinate to be in [0, ..., FIELD_SIZE-1]
    require(p[0] < FIELD_SIZE, "invalid x-ordinate");
    require(p[1] < FIELD_SIZE, "invalid y-ordinate");
    return ySquared(p[0]) == mulmod(p[1], p[1], FIELD_SIZE);
  }

  // Hash x uniformly into {0, ..., FIELD_SIZE-1}.
  function fieldHash(bytes memory b) internal pure returns (uint256 x_) {
    x_ = uint256(keccak256(b));
    // Rejecting if x >= FIELD_SIZE corresponds to step 2.1 in section 2.3.4 of
    // http://www.secg.org/sec1-v2.pdf , which is part of the definition of
    // string_to_point in the IETF draft
    while (x_ >= FIELD_SIZE) {
      x_ = uint256(keccak256(abi.encodePacked(x_)));
    }
  }

  // Hash b to a random point which hopefully lies on secp256k1. The y ordinate
  // is always even, due to
  // https://datatracker.ietf.org/doc/html/draft-irtf-cfrg-vrf-05#section-5.4.1.1
  // step 5.C, which references arbitrary_string_to_point, defined in
  // https://datatracker.ietf.org/doc/html/draft-irtf-cfrg-vrf-05#section-5.5 as
  // returning the point with given x ordinate, and even y ordinate.
  function newCandidateSecp256k1Point(bytes memory b) internal view returns (uint256[2] memory p) {
    unchecked {
      p[0] = fieldHash(b);
      p[1] = squareRoot(ySquared(p[0]));
      if (p[1] % 2 == 1) {
        // Note that 0 <= p[1] < FIELD_SIZE
        // so this cannot wrap, we use unchecked to save gas.
        p[1] = FIELD_SIZE - p[1];
      }
    }
  }

  // Domain-separation tag for initial hash in hashToCurve. Corresponds to
  // vrf.go/hashToCurveHashPrefix
  uint256 internal constant HASH_TO_CURVE_HASH_PREFIX = 1;

  // Cryptographic hash function onto the curve.
  //
  // Corresponds to algorithm in section 5.4.1.1 of the draft standard. (But see
  // DESIGN NOTES above for slight differences.)
  //
  // TODO(alx): Implement a bounded-computation hash-to-curve, as described in
  // "Construction of Rational Points on Elliptic Curves over Finite Fields"
  // http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.831.5299&rep=rep1&type=pdf
  // and suggested by
  // https://datatracker.ietf.org/doc/html/draft-irtf-cfrg-hash-to-curve-01#section-5.2.2
  // (Though we can't used exactly that because secp256k1's j-invariant is 0.)
  //
  // This would greatly simplify the analysis in "OTHER SECURITY CONSIDERATIONS"
  // https://www.pivotaltracker.com/story/show/171120900
  function hashToCurve(uint256[2] memory pk, uint256 input) internal view returns (uint256[2] memory rv) {
    rv = newCandidateSecp256k1Point(abi.encodePacked(HASH_TO_CURVE_HASH_PREFIX, pk, input));
    while (!isOnCurve(rv)) {
      rv = newCandidateSecp256k1Point(abi.encodePacked(rv[0]));
    }
  }

  /** *********************************************************************
   * @notice Check that product==scalar*multiplicand
   *
   * @dev Based on Vitalik Buterin's idea in ethresear.ch post cited below.
   *
   * @param multiplicand: secp256k1 point
   * @param scalar: non-zero GF(GROUP_ORDER) scalar
   * @param product: secp256k1 expected to be multiplier * multiplicand
   * @return verifies true iff product==scalar*multiplicand, with cryptographically high probability
   */
  function ecmulVerify(
    uint256[2] memory multiplicand,
    uint256 scalar,
    uint256[2] memory product
  ) internal pure returns (bool verifies) {
    require(scalar != 0, "zero scalar"); // Rules out an ecrecover failure case
    uint256 x = multiplicand[0]; // x ordinate of multiplicand
    uint8 v = multiplicand[1] % 2 == 0 ? 27 : 28; // parity of y ordinate
    // https://ethresear.ch/t/you-can-kinda-abuse-ecrecover-to-do-ecmul-in-secp256k1-today/2384/9
    // Point corresponding to address ecrecover(0, v, x, s=scalar*x) is
    // (x⁻¹ mod GROUP_ORDER) * (scalar * x * multiplicand - 0 * g), i.e.
    // scalar*multiplicand. See https://crypto.stackexchange.com/a/18106
    bytes32 scalarTimesX = bytes32(mulmod(scalar, x, GROUP_ORDER));
    address actual = ecrecover(bytes32(0), v, bytes32(x), scalarTimesX);
    // Explicit conversion to address takes bottom 160 bits
    address expected = address(uint160(uint256(keccak256(abi.encodePacked(product)))));
    return (actual == expected);
  }

  // Returns x1/z1-x2/z2=(x1z2-x2z1)/(z1z2) in projective coordinates on P¹(𝔽ₙ)
  function projectiveSub(
    uint256 x1,
    uint256 z1,
    uint256 x2,
    uint256 z2
  ) internal pure returns (uint256 x3, uint256 z3) {
    unchecked {
      uint256 num1 = mulmod(z2, x1, FIELD_SIZE);
      // Note this cannot wrap since x2 is a point in [0, FIELD_SIZE-1]
      // we use unchecked to save gas.
      uint256 num2 = mulmod(FIELD_SIZE - x2, z1, FIELD_SIZE);
      (x3, z3) = (addmod(num1, num2, FIELD_SIZE), mulmod(z1, z2, FIELD_SIZE));
    }
  }

  // Returns x1/z1*x2/z2=(x1x2)/(z1z2), in projective coordinates on P¹(𝔽ₙ)
  function projectiveMul(
    uint256 x1,
    uint256 z1,
    uint256 x2,
    uint256 z2
  ) internal pure returns (uint256 x3, uint256 z3) {
    (x3, z3) = (mulmod(x1, x2, FIELD_SIZE), mulmod(z1, z2, FIELD_SIZE));
  }

  /** **************************************************************************
        @notice Computes elliptic-curve sum, in projective co-ordinates

        @dev Using projective coordinates avoids costly divisions

        @dev To use this with p and q in affine coordinates, call
        @dev projectiveECAdd(px, py, qx, qy). This will return
        @dev the addition of (px, py, 1) and (qx, qy, 1), in the
        @dev secp256k1 group.

        @dev This can be used to calculate the z which is the inverse to zInv
        @dev in isValidVRFOutput. But consider using a faster
        @dev re-implementation such as ProjectiveECAdd in the golang vrf package.

        @dev This function assumes [px,py,1],[qx,qy,1] are valid projective
             coordinates of secp256k1 points. That is safe in this contract,
             because this method is only used by linearCombination, which checks
             points are on the curve via ecrecover.
        **************************************************************************
        @param px The first affine coordinate of the first summand
        @param py The second affine coordinate of the first summand
        @param qx The first affine coordinate of the second summand
        @param qy The second affine coordinate of the second summand

        (px,py) and (qx,qy) must be distinct, valid secp256k1 points.
        **************************************************************************
        Return values are projective coordinates of [px,py,1]+[qx,qy,1] as points
        on secp256k1, in P²(𝔽ₙ)
        @return sx
        @return sy
        @return sz
    */
  function projectiveECAdd(
    uint256 px,
    uint256 py,
    uint256 qx,
    uint256 qy
  )
    internal
    pure
    returns (
      uint256 sx,
      uint256 sy,
      uint256 sz
    )
  {
    unchecked {
      // See "Group law for E/K : y^2 = x^3 + ax + b", in section 3.1.2, p. 80,
      // "Guide to Elliptic Curve Cryptography" by Hankerson, Menezes and Vanstone
      // We take the equations there for (sx,sy), and homogenize them to
      // projective coordinates. That way, no inverses are required, here, and we
      // only need the one inverse in affineECAdd.

      // We only need the "point addition" equations from Hankerson et al. Can
      // skip the "point doubling" equations because p1 == p2 is cryptographically
      // impossible, and required not to be the case in linearCombination.

      // Add extra "projective coordinate" to the two points
      (uint256 z1, uint256 z2) = (1, 1);

      // (lx, lz) = (qy-py)/(qx-px), i.e., gradient of secant line.
      // Cannot wrap since px and py are in [0, FIELD_SIZE-1]
      uint256 lx = addmod(qy, FIELD_SIZE - py, FIELD_SIZE);
      uint256 lz = addmod(qx, FIELD_SIZE - px, FIELD_SIZE);

      uint256 dx; // Accumulates denominator from sx calculation
      // sx=((qy-py)/(qx-px))^2-px-qx
      (sx, dx) = projectiveMul(lx, lz, lx, lz); // ((qy-py)/(qx-px))^2
      (sx, dx) = projectiveSub(sx, dx, px, z1); // ((qy-py)/(qx-px))^2-px
      (sx, dx) = projectiveSub(sx, dx, qx, z2); // ((qy-py)/(qx-px))^2-px-qx

      uint256 dy; // Accumulates denominator from sy calculation
      // sy=((qy-py)/(qx-px))(px-sx)-py
      (sy, dy) = projectiveSub(px, z1, sx, dx); // px-sx
      (sy, dy) = projectiveMul(sy, dy, lx, lz); // ((qy-py)/(qx-px))(px-sx)
      (sy, dy) = projectiveSub(sy, dy, py, z1); // ((qy-py)/(qx-px))(px-sx)-py

      if (dx != dy) {
        // Cross-multiply to put everything over a common denominator
        sx = mulmod(sx, dy, FIELD_SIZE);
        sy = mulmod(sy, dx, FIELD_SIZE);
        sz = mulmod(dx, dy, FIELD_SIZE);
      } else {
        // Already over a common denominator, use that for z ordinate
        sz = dx;
      }
    }
  }

  // p1+p2, as affine points on secp256k1.
  //
  // invZ must be the inverse of the z returned by projectiveECAdd(p1, p2).
  // It is computed off-chain to save gas.
  //
  // p1 and p2 must be distinct, because projectiveECAdd doesn't handle
  // point doubling.
  function affineECAdd(
    uint256[2] memory p1,
    uint256[2] memory p2,
    uint256 invZ
  ) internal pure returns (uint256[2] memory) {
    uint256 x;
    uint256 y;
    uint256 z;
    (x, y, z) = projectiveECAdd(p1[0], p1[1], p2[0], p2[1]);
    require(mulmod(z, invZ, FIELD_SIZE) == 1, "invZ must be inverse of z");
    // Clear the z ordinate of the projective representation by dividing through
    // by it, to obtain the affine representation
    return [mulmod(x, invZ, FIELD_SIZE), mulmod(y, invZ, FIELD_SIZE)];
  }

  // True iff address(c*p+s*g) == lcWitness, where g is generator. (With
  // cryptographically high probability.)
  function verifyLinearCombinationWithGenerator(
    uint256 c,
    uint256[2] memory p,
    uint256 s,
    address lcWitness
  ) internal pure returns (bool) {
    // Rule out ecrecover failure modes which return address 0.
    unchecked {
      require(lcWitness != address(0), "bad witness");
      uint8 v = (p[1] % 2 == 0) ? 27 : 28; // parity of y-ordinate of p
      // Note this cannot wrap (X - Y % X), but we use unchecked to save
      // gas.
      bytes32 pseudoHash = bytes32(GROUP_ORDER - mulmod(p[0], s, GROUP_ORDER)); // -s*p[0]
      bytes32 pseudoSignature = bytes32(mulmod(c, p[0], GROUP_ORDER)); // c*p[0]
      // https://ethresear.ch/t/you-can-kinda-abuse-ecrecover-to-do-ecmul-in-secp256k1-today/2384/9
      // The point corresponding to the address returned by
      // ecrecover(-s*p[0],v,p[0],c*p[0]) is
      // (p[0]⁻¹ mod GROUP_ORDER)*(c*p[0]-(-s)*p[0]*g)=c*p+s*g.
      // See https://crypto.stackexchange.com/a/18106
      // https://bitcoin.stackexchange.com/questions/38351/ecdsa-v-r-s-what-is-v
      address computed = ecrecover(pseudoHash, v, bytes32(p[0]), pseudoSignature);
      return computed == lcWitness;
    }
  }

  // c*p1 + s*p2. Requires cp1Witness=c*p1 and sp2Witness=s*p2. Also
  // requires cp1Witness != sp2Witness (which is fine for this application,
  // since it is cryptographically impossible for them to be equal. In the
  // (cryptographically impossible) case that a prover accidentally derives
  // a proof with equal c*p1 and s*p2, they should retry with a different
  // proof nonce.) Assumes that all points are on secp256k1
  // (which is checked in verifyVRFProof below.)
  function linearCombination(
    uint256 c,
    uint256[2] memory p1,
    uint256[2] memory cp1Witness,
    uint256 s,
    uint256[2] memory p2,
    uint256[2] memory sp2Witness,
    uint256 zInv
  ) internal pure returns (uint256[2] memory) {
    unchecked {
      // Note we are relying on the wrap around here
      require((cp1Witness[0] % FIELD_SIZE) != (sp2Witness[0] % FIELD_SIZE), "points in sum must be distinct");
      require(ecmulVerify(p1, c, cp1Witness), "First mul check failed");
      require(ecmulVerify(p2, s, sp2Witness), "Second mul check failed");
      return affineECAdd(cp1Witness, sp2Witness, zInv);
    }
  }

  // Domain-separation tag for the hash taken in scalarFromCurvePoints.
  // Corresponds to scalarFromCurveHashPrefix in vrf.go
  uint256 internal constant SCALAR_FROM_CURVE_POINTS_HASH_PREFIX = 2;

  // Pseudo-random number from inputs. Matches vrf.go/scalarFromCurvePoints, and
  // https://datatracker.ietf.org/doc/html/draft-irtf-cfrg-vrf-05#section-5.4.3
  // The draft calls (in step 7, via the definition of string_to_int, in
  // https://datatracker.ietf.org/doc/html/rfc8017#section-4.2 ) for taking the
  // first hash without checking that it corresponds to a number less than the
  // group order, which will lead to a slight bias in the sample.
  //
  // TODO(alx): We could save a bit of gas by following the standard here and
  // using the compressed representation of the points, if we collated the y
  // parities into a single bytes32.
  // https://www.pivotaltracker.com/story/show/171120588
  function scalarFromCurvePoints(
    uint256[2] memory hash,
    uint256[2] memory pk,
    uint256[2] memory gamma,
    address uWitness,
    uint256[2] memory v
  ) internal pure returns (uint256 s) {
    return uint256(keccak256(abi.encodePacked(SCALAR_FROM_CURVE_POINTS_HASH_PREFIX, hash, pk, gamma, v, uWitness)));
  }

  // True if (gamma, c, s) is a correctly constructed randomness proof from pk
  // and seed. zInv must be the inverse of the third ordinate from
  // projectiveECAdd applied to cGammaWitness and sHashWitness. Corresponds to
  // section 5.3 of the IETF draft.
  //
  // TODO(alx): Since I'm only using pk in the ecrecover call, I could only pass
  // the x ordinate, and the parity of the y ordinate in the top bit of uWitness
  // (which I could make a uint256 without using any extra space.) Would save
  // about 2000 gas. https://www.pivotaltracker.com/story/show/170828567
  function verifyVRFProof(
    uint256[2] memory pk,
    uint256[2] memory gamma,
    uint256 c,
    uint256 s,
    uint256 seed,
    address uWitness,
    uint256[2] memory cGammaWitness,
    uint256[2] memory sHashWitness,
    uint256 zInv
  ) internal view {
    unchecked {
      require(isOnCurve(pk), "public key is not on curve");
      require(isOnCurve(gamma), "gamma is not on curve");
      require(isOnCurve(cGammaWitness), "cGammaWitness is not on curve");
      require(isOnCurve(sHashWitness), "sHashWitness is not on curve");
      // Step 5. of IETF draft section 5.3 (pk corresponds to 5.3's Y, and here
      // we use the address of u instead of u itself. Also, here we add the
      // terms instead of taking the difference, and in the proof construction in
      // vrf.GenerateProof, we correspondingly take the difference instead of
      // taking the sum as they do in step 7 of section 5.1.)
      require(verifyLinearCombinationWithGenerator(c, pk, s, uWitness), "addr(c*pk+s*g)!=_uWitness");
      // Step 4. of IETF draft section 5.3 (pk corresponds to Y, seed to alpha_string)
      uint256[2] memory hash = hashToCurve(pk, seed);
      // Step 6. of IETF draft section 5.3, but see note for step 5 about +/- terms
      uint256[2] memory v = linearCombination(c, gamma, cGammaWitness, s, hash, sHashWitness, zInv);
      // Steps 7. and 8. of IETF draft section 5.3
      uint256 derivedC = scalarFromCurvePoints(hash, pk, gamma, uWitness, v);
      require(c == derivedC, "invalid proof");
    }
  }

  // Domain-separation tag for the hash used as the final VRF output.
  // Corresponds to vrfRandomOutputHashPrefix in vrf.go
  uint256 internal constant VRF_RANDOM_OUTPUT_HASH_PREFIX = 3;

  struct Proof {
    uint256[2] pk;
    uint256[2] gamma;
    uint256 c;
    uint256 s;
    uint256 seed;
    address uWitness;
    uint256[2] cGammaWitness;
    uint256[2] sHashWitness;
    uint256 zInv;
  }

  /* ***************************************************************************
     * @notice Returns proof's output, if proof is valid. Otherwise reverts

     * @param proof vrf proof components
     * @param seed  seed used to generate the vrf output
     *
     * Throws if proof is invalid, otherwise:
     * @return output i.e., the random output implied by the proof
     * ***************************************************************************
     */
  function randomValueFromVRFProof(Proof memory proof, uint256 seed) internal view returns (uint256 output) {
    verifyVRFProof(
      proof.pk,
      proof.gamma,
      proof.c,
      proof.s,
      seed,
      proof.uWitness,
      proof.cGammaWitness,
      proof.sHashWitness,
      proof.zInv
    );
    output = uint256(keccak256(abi.encode(VRF_RANDOM_OUTPUT_HASH_PREFIX, proof.gamma)));
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ConfirmedOwnerWithProposal.sol";

/**
 * @title The ConfirmedOwner contract
 * @notice A contract with helpers for basic contract ownership.
 */
contract ConfirmedOwner is ConfirmedOwnerWithProposal {
  constructor(address newOwner) ConfirmedOwnerWithProposal(newOwner, address(0)) {}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/OwnableInterface.sol";

/**
 * @title The ConfirmedOwner contract
 * @notice A contract with helpers for basic contract ownership.
 */
contract ConfirmedOwnerWithProposal is OwnableInterface {
  address private s_owner;
  address private s_pendingOwner;

  event OwnershipTransferRequested(address indexed from, address indexed to);
  event OwnershipTransferred(address indexed from, address indexed to);

  constructor(address newOwner, address pendingOwner) {
    require(newOwner != address(0), "Cannot set owner to zero");

    s_owner = newOwner;
    if (pendingOwner != address(0)) {
      _transferOwnership(pendingOwner);
    }
  }

  /**
   * @notice Allows an owner to begin transferring ownership to a new address,
   * pending.
   */
  function transferOwnership(address to) public override onlyOwner {
    _transferOwnership(to);
  }

  /**
   * @notice Allows an ownership transfer to be completed by the recipient.
   */
  function acceptOwnership() external override {
    require(msg.sender == s_pendingOwner, "Must be proposed owner");

    address oldOwner = s_owner;
    s_owner = msg.sender;
    s_pendingOwner = address(0);

    emit OwnershipTransferred(oldOwner, msg.sender);
  }

  /**
   * @notice Get the current owner
   */
  function owner() public view override returns (address) {
    return s_owner;
  }

  /**
   * @notice validate, transfer ownership, and emit relevant events
   */
  function _transferOwnership(address to) private {
    require(to != msg.sender, "Cannot transfer to self");

    s_pendingOwner = to;

    emit OwnershipTransferRequested(s_owner, to);
  }

  /**
   * @notice validate access
   */
  function _validateOwnership() internal view {
    require(msg.sender == s_owner, "Only callable by owner");
  }

  /**
   * @notice Reverts if called by anyone other than the contract owner.
   */
  modifier onlyOwner() {
    _validateOwnership();
    _;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface OwnableInterface {
  function owner() external returns (address);

  function transferOwnership(address recipient) external;

  function acceptOwnership() external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../dev/VRFCoordinatorV2.sol";

contract VRFCoordinatorV2TestHelper is VRFCoordinatorV2 {
  uint96 s_paymentAmount;
  uint256 s_gasStart;

  constructor(
    address link,
    address blockhashStore,
    address linkEthFeed
  )
    // solhint-disable-next-line no-empty-blocks
    VRFCoordinatorV2(link, blockhashStore, linkEthFeed)
  {
    /* empty */
  }

  function calculatePaymentAmountTest(
    uint256 gasAfterPaymentCalculation,
    uint32 fulfillmentFlatFeeLinkPPM,
    uint256 weiPerUnitGas
  ) external {
    s_paymentAmount = calculatePaymentAmount(
      gasleft(),
      gasAfterPaymentCalculation,
      fulfillmentFlatFeeLinkPPM,
      weiPerUnitGas
    );
  }

  function getPaymentAmount() public view returns (uint96) {
    return s_paymentAmount;
  }

  function getGasStart() public view returns (uint256) {
    return s_gasStart;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ConfirmedOwner.sol";
import "./interfaces/AggregatorValidatorInterface.sol";
import "./interfaces/TypeAndVersionInterface.sol";

contract ValidatorProxy is AggregatorValidatorInterface, TypeAndVersionInterface, ConfirmedOwner {
  /// @notice Uses a single storage slot to store the current address
  struct AggregatorConfiguration {
    address target;
    bool hasNewProposal;
  }

  struct ValidatorConfiguration {
    AggregatorValidatorInterface target;
    bool hasNewProposal;
  }

  // Configuration for the current aggregator
  AggregatorConfiguration private s_currentAggregator;
  // Proposed aggregator address
  address private s_proposedAggregator;

  // Configuration for the current validator
  ValidatorConfiguration private s_currentValidator;
  // Proposed validator address
  AggregatorValidatorInterface private s_proposedValidator;

  event AggregatorProposed(address indexed aggregator);
  event AggregatorUpgraded(address indexed previous, address indexed current);
  event ValidatorProposed(AggregatorValidatorInterface indexed validator);
  event ValidatorUpgraded(AggregatorValidatorInterface indexed previous, AggregatorValidatorInterface indexed current);
  /// @notice The proposed aggregator called validate, but the call was not passed on to any validators
  event ProposedAggregatorValidateCall(
    address indexed proposed,
    uint256 previousRoundId,
    int256 previousAnswer,
    uint256 currentRoundId,
    int256 currentAnswer
  );

  /**
   * @notice Construct the ValidatorProxy with an aggregator and a validator
   * @param aggregator address
   * @param validator address
   */
  constructor(address aggregator, AggregatorValidatorInterface validator) ConfirmedOwner(msg.sender) {
    s_currentAggregator = AggregatorConfiguration({target: aggregator, hasNewProposal: false});
    s_currentValidator = ValidatorConfiguration({target: validator, hasNewProposal: false});
  }

  /**
   * @notice Validate a transmission
   * @dev Must be called by either the `s_currentAggregator.target`, or the `s_proposedAggregator`.
   * If called by the `s_currentAggregator.target` this function passes the call on to the `s_currentValidator.target`
   * and the `s_proposedValidator`, if it is set.
   * If called by the `s_proposedAggregator` this function emits a `ProposedAggregatorValidateCall` to signal that
   * the call was received.
   * @dev To guard against external `validate` calls reverting, we use raw calls here.
   * We favour `call` over try-catch to ensure that failures are avoided even if the validator address is incorrectly
   * set as a non-contract address.
   * @dev If the `aggregator` and `validator` are the same contract or collude, this could exhibit reentrancy behavior.
   * However, since that contract would have to be explicitly written for reentrancy and that the `owner` would have
   * to configure this contract to use that malicious contract, we refrain from using mutex or check here.
   * @dev This does not perform any checks on any roundId, so it is possible that a validator receive different reports
   * for the same roundId at different points in time. Validator implementations should be aware of this.
   * @param previousRoundId uint256
   * @param previousAnswer int256
   * @param currentRoundId uint256
   * @param currentAnswer int256
   * @return bool
   */
  function validate(
    uint256 previousRoundId,
    int256 previousAnswer,
    uint256 currentRoundId,
    int256 currentAnswer
  ) external override returns (bool) {
    address currentAggregator = s_currentAggregator.target;
    if (msg.sender != currentAggregator) {
      address proposedAggregator = s_proposedAggregator;
      require(msg.sender == proposedAggregator, "Not a configured aggregator");
      // If the aggregator is still in proposed state, emit an event and don't push to any validator.
      // This is to confirm that `validate` is being called prior to upgrade.
      emit ProposedAggregatorValidateCall(
        proposedAggregator,
        previousRoundId,
        previousAnswer,
        currentRoundId,
        currentAnswer
      );
      return true;
    }

    // Send the validate call to the current validator
    ValidatorConfiguration memory currentValidator = s_currentValidator;
    address currentValidatorAddress = address(currentValidator.target);
    require(currentValidatorAddress != address(0), "No validator set");
    currentValidatorAddress.call(
      abi.encodeWithSelector(
        AggregatorValidatorInterface.validate.selector,
        previousRoundId,
        previousAnswer,
        currentRoundId,
        currentAnswer
      )
    );
    // If there is a new proposed validator, send the validate call to that validator also
    if (currentValidator.hasNewProposal) {
      address(s_proposedValidator).call(
        abi.encodeWithSelector(
          AggregatorValidatorInterface.validate.selector,
          previousRoundId,
          previousAnswer,
          currentRoundId,
          currentAnswer
        )
      );
    }
    return true;
  }

  /** AGGREGATOR CONFIGURATION FUNCTIONS **/

  /**
   * @notice Propose an aggregator
   * @dev A zero address can be used to unset the proposed aggregator. Only owner can call.
   * @param proposed address
   */
  function proposeNewAggregator(address proposed) external onlyOwner {
    require(s_proposedAggregator != proposed && s_currentAggregator.target != proposed, "Invalid proposal");
    s_proposedAggregator = proposed;
    // If proposed is zero address, hasNewProposal = false
    s_currentAggregator.hasNewProposal = (proposed != address(0));
    emit AggregatorProposed(proposed);
  }

  /**
   * @notice Upgrade the aggregator by setting the current aggregator as the proposed aggregator.
   * @dev Must have a proposed aggregator. Only owner can call.
   */
  function upgradeAggregator() external onlyOwner {
    // Get configuration in memory
    AggregatorConfiguration memory current = s_currentAggregator;
    address previous = current.target;
    address proposed = s_proposedAggregator;

    // Perform the upgrade
    require(current.hasNewProposal, "No proposal");
    s_currentAggregator = AggregatorConfiguration({target: proposed, hasNewProposal: false});
    delete s_proposedAggregator;

    emit AggregatorUpgraded(previous, proposed);
  }

  /**
   * @notice Get aggregator details
   * @return current address
   * @return hasProposal bool
   * @return proposed address
   */
  function getAggregators()
    external
    view
    returns (
      address current,
      bool hasProposal,
      address proposed
    )
  {
    current = s_currentAggregator.target;
    hasProposal = s_currentAggregator.hasNewProposal;
    proposed = s_proposedAggregator;
  }

  /** VALIDATOR CONFIGURATION FUNCTIONS **/

  /**
   * @notice Propose an validator
   * @dev A zero address can be used to unset the proposed validator. Only owner can call.
   * @param proposed address
   */
  function proposeNewValidator(AggregatorValidatorInterface proposed) external onlyOwner {
    require(s_proposedValidator != proposed && s_currentValidator.target != proposed, "Invalid proposal");
    s_proposedValidator = proposed;
    // If proposed is zero address, hasNewProposal = false
    s_currentValidator.hasNewProposal = (address(proposed) != address(0));
    emit ValidatorProposed(proposed);
  }

  /**
   * @notice Upgrade the validator by setting the current validator as the proposed validator.
   * @dev Must have a proposed validator. Only owner can call.
   */
  function upgradeValidator() external onlyOwner {
    // Get configuration in memory
    ValidatorConfiguration memory current = s_currentValidator;
    AggregatorValidatorInterface previous = current.target;
    AggregatorValidatorInterface proposed = s_proposedValidator;

    // Perform the upgrade
    require(current.hasNewProposal, "No proposal");
    s_currentValidator = ValidatorConfiguration({target: proposed, hasNewProposal: false});
    delete s_proposedValidator;

    emit ValidatorUpgraded(previous, proposed);
  }

  /**
   * @notice Get validator details
   * @return current address
   * @return hasProposal bool
   * @return proposed address
   */
  function getValidators()
    external
    view
    returns (
      AggregatorValidatorInterface current,
      bool hasProposal,
      AggregatorValidatorInterface proposed
    )
  {
    current = s_currentValidator.target;
    hasProposal = s_currentValidator.hasNewProposal;
    proposed = s_proposedValidator;
  }

  /**
   * @notice The type and version of this contract
   * @return Type and version string
   */
  function typeAndVersion() external pure virtual override returns (string memory) {
    return "ValidatorProxy 1.0.0";
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface AggregatorValidatorInterface {
  function validate(
    uint256 previousRoundId,
    int256 previousAnswer,
    uint256 currentRoundId,
    int256 currentAnswer
  ) external returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/TypeAndVersionInterface.sol";
import "../interfaces/AggregatorValidatorInterface.sol";
import "../interfaces/AccessControllerInterface.sol";
import "../SimpleWriteAccessController.sol";

/* ./dev dependencies - to be moved from ./dev after audit */
import "./interfaces/FlagsInterface.sol";
import "./interfaces/ForwarderInterface.sol";
import "./vendor/@eth-optimism/contracts/0.4.7/contracts/optimistic-ethereum/iOVM/bridge/messaging/iOVM_CrossDomainMessenger.sol";

/**
 * @title OptimismValidator - makes xDomain L2 Flags contract call (using L2 xDomain Forwarder contract)
 * @notice Allows to raise and lower Flags on the Optimism L2 network through L1 bridge
 *  - The internal AccessController controls the access of the validate method
 */
contract OptimismValidator is TypeAndVersionInterface, AggregatorValidatorInterface, SimpleWriteAccessController {
  /// @dev Follows: https://eips.ethereum.org/EIPS/eip-1967
  address public constant FLAG_OPTIMISM_SEQ_OFFLINE =
    address(bytes20(bytes32(uint256(keccak256("chainlink.flags.optimism-seq-offline")) - 1)));
  // Encode underlying Flags call/s
  bytes private constant CALL_RAISE_FLAG =
    abi.encodeWithSelector(FlagsInterface.raiseFlag.selector, FLAG_OPTIMISM_SEQ_OFFLINE);
  bytes private constant CALL_LOWER_FLAG =
    abi.encodeWithSelector(FlagsInterface.lowerFlag.selector, FLAG_OPTIMISM_SEQ_OFFLINE);
  uint32 private constant CALL_GAS_LIMIT = 1_200_000;
  int256 private constant ANSWER_SEQ_OFFLINE = 1;

  address public immutable CROSS_DOMAIN_MESSENGER;
  address public immutable L2_CROSS_DOMAIN_FORWARDER;
  address public immutable L2_FLAGS;

  /**
   * @param crossDomainMessengerAddr address the xDomain bridge messenger (Optimism bridge L1) contract address
   * @param l2CrossDomainForwarderAddr the L2 Forwarder contract address
   * @param l2FlagsAddr the L2 Flags contract address
   */
  constructor(
    address crossDomainMessengerAddr,
    address l2CrossDomainForwarderAddr,
    address l2FlagsAddr
  ) {
    require(crossDomainMessengerAddr != address(0), "Invalid xDomain Messenger address");
    require(l2CrossDomainForwarderAddr != address(0), "Invalid L2 xDomain Forwarder address");
    require(l2FlagsAddr != address(0), "Invalid L2 Flags address");
    CROSS_DOMAIN_MESSENGER = crossDomainMessengerAddr;
    L2_CROSS_DOMAIN_FORWARDER = l2CrossDomainForwarderAddr;
    L2_FLAGS = l2FlagsAddr;
  }

  /**
   * @notice versions:
   *
   * - OptimismValidator 0.1.0: initial release
   *
   * @inheritdoc TypeAndVersionInterface
   */
  function typeAndVersion() external pure virtual override returns (string memory) {
    return "OptimismValidator 0.1.0";
  }

  /**
   * @notice validate method sends an xDomain L2 tx to update Flags contract, in case of change from `previousAnswer`.
   * @dev A message is sent via the Optimism CrossDomainMessenger L1 contract. The "payment" for L2 execution happens on L1,
   *   using the gas attached to this tx (some extra gas is burned by the Optimism bridge to avoid DoS attacks).
   *   This method is accessed controlled.
   * @param previousAnswer previous aggregator answer
   * @param currentAnswer new aggregator answer - value of 1 considers the service offline.
   */
  function validate(
    uint256, /* previousRoundId */
    int256 previousAnswer,
    uint256, /* currentRoundId */
    int256 currentAnswer
  ) external override checkAccess returns (bool) {
    // Avoids resending to L2 the same tx on every call
    if (previousAnswer == currentAnswer) {
      return true; // noop
    }

    // Encode the Forwarder call
    bytes4 selector = ForwarderInterface.forward.selector;
    address target = L2_FLAGS;
    // Choose and encode the underlying Flags call
    bytes memory data = currentAnswer == ANSWER_SEQ_OFFLINE ? CALL_RAISE_FLAG : CALL_LOWER_FLAG;
    bytes memory message = abi.encodeWithSelector(selector, target, data);
    // Make the xDomain call
    iOVM_CrossDomainMessenger(CROSS_DOMAIN_MESSENGER).sendMessage(L2_CROSS_DOMAIN_FORWARDER, message, CALL_GAS_LIMIT);
    // return success
    return true;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface AccessControllerInterface {
  function hasAccess(address user, bytes calldata data) external view returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ConfirmedOwner.sol";
import "./interfaces/AccessControllerInterface.sol";

/**
 * @title SimpleWriteAccessController
 * @notice Gives access to accounts explicitly added to an access list by the
 * controller's owner.
 * @dev does not make any special permissions for externally, see
 * SimpleReadAccessController for that.
 */
contract SimpleWriteAccessController is AccessControllerInterface, ConfirmedOwner {
  bool public checkEnabled;
  mapping(address => bool) internal accessList;

  event AddedAccess(address user);
  event RemovedAccess(address user);
  event CheckAccessEnabled();
  event CheckAccessDisabled();

  constructor() ConfirmedOwner(msg.sender) {
    checkEnabled = true;
  }

  /**
   * @notice Returns the access of an address
   * @param _user The address to query
   */
  function hasAccess(address _user, bytes memory) public view virtual override returns (bool) {
    return accessList[_user] || !checkEnabled;
  }

  /**
   * @notice Adds an address to the access list
   * @param _user The address to add
   */
  function addAccess(address _user) external onlyOwner {
    if (!accessList[_user]) {
      accessList[_user] = true;

      emit AddedAccess(_user);
    }
  }

  /**
   * @notice Removes an address from the access list
   * @param _user The address to remove
   */
  function removeAccess(address _user) external onlyOwner {
    if (accessList[_user]) {
      accessList[_user] = false;

      emit RemovedAccess(_user);
    }
  }

  /**
   * @notice makes the access check enforced
   */
  function enableAccessCheck() external onlyOwner {
    if (!checkEnabled) {
      checkEnabled = true;

      emit CheckAccessEnabled();
    }
  }

  /**
   * @notice makes the access check unenforced
   */
  function disableAccessCheck() external onlyOwner {
    if (checkEnabled) {
      checkEnabled = false;

      emit CheckAccessDisabled();
    }
  }

  /**
   * @dev reverts if the caller does not have access
   */
  modifier checkAccess() {
    require(hasAccess(msg.sender, msg.data), "No access");
    _;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface FlagsInterface {
  function getFlag(address) external view returns (bool);

  function getFlags(address[] calldata) external view returns (bool[] memory);

  function raiseFlag(address) external;

  function raiseFlags(address[] calldata) external;

  function lowerFlag(address) external;

  function lowerFlags(address[] calldata) external;

  function setRaisingAccessController(address) external;

  function setLoweringAccessController(address) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title ForwarderInterface - forwards a call to a target, under some conditions
interface ForwarderInterface {
  /**
   * @notice forward calls the `target` with `data`
   * @param target contract address to be called
   * @param data to send to target contract
   */
  function forward(address target, bytes memory data) external;
}

pragma solidity >=0.7.6 <0.9.0;

/**
 * @title iOVM_CrossDomainMessenger
 */
interface iOVM_CrossDomainMessenger {
  /**********
   * Events *
   **********/

  event SentMessage(bytes message);
  event RelayedMessage(bytes32 msgHash);
  event FailedRelayedMessage(bytes32 msgHash);

  /*************
   * Variables *
   *************/

  function xDomainMessageSender() external view returns (address);

  /********************
   * Public Functions *
   ********************/

  /**
   * Sends a cross domain message to the target messenger.
   * @param _target Target contract address.
   * @param _message Message to send to the target.
   * @param _gasLimit Gas limit for the provided message.
   */
  function sendMessage(
    address _target,
    bytes calldata _message,
    uint32 _gasLimit
  ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/DelegateForwarderInterface.sol";
import "./vendor/@eth-optimism/contracts/0.4.7/contracts/optimistic-ethereum/iOVM/bridge/messaging/iOVM_CrossDomainMessenger.sol";
import "./vendor/openzeppelin-solidity/v4.3.1/contracts/utils/Address.sol";
import "./OptimismCrossDomainForwarder.sol";

/**
 * @title OptimismCrossDomainGovernor - L1 xDomain account representation (with delegatecall support) for Optimism
 * @notice L2 Contract which receives messages from a specific L1 address and transparently forwards them to the destination.
 * @dev Any other L2 contract which uses this contract's address as a privileged position,
 *   can be considered to be simultaneously owned by the `l1Owner` and L2 `owner`
 */
contract OptimismCrossDomainGovernor is DelegateForwarderInterface, OptimismCrossDomainForwarder {
  /**
   * @notice creates a new Optimism xDomain Forwarder contract
   * @param crossDomainMessengerAddr the xDomain bridge messenger (Optimism bridge L2) contract address
   * @param l1OwnerAddr the L1 owner address that will be allowed to call the forward fn
   * @dev Empty constructor required due to inheriting from abstract contract CrossDomainForwarder
   */
  constructor(iOVM_CrossDomainMessenger crossDomainMessengerAddr, address l1OwnerAddr)
    OptimismCrossDomainForwarder(crossDomainMessengerAddr, l1OwnerAddr)
  {}

  /**
   * @notice versions:
   *
   * - OptimismCrossDomainForwarder 1.0.0: initial release
   *
   * @inheritdoc TypeAndVersionInterface
   */
  function typeAndVersion() external pure virtual override returns (string memory) {
    return "OptimismCrossDomainGovernor 1.0.0";
  }

  /**
   * @dev forwarded only if L2 Messenger calls with `msg.sender` being the L1 owner address, or called by the L2 owner
   * @inheritdoc ForwarderInterface
   */
  function forward(address target, bytes memory data) external override onlyLocalOrCrossDomainOwner {
    Address.functionCall(target, data, "Governor call reverted");
  }

  /**
   * @dev forwarded only if L2 Messenger calls with `msg.sender` being the L1 owner address, or called by the L2 owner
   * @inheritdoc DelegateForwarderInterface
   */
  function forwardDelegate(address target, bytes memory data) external override onlyLocalOrCrossDomainOwner {
    Address.functionDelegateCall(target, data, "Governor delegatecall reverted");
  }

  /**
   * @notice The call MUST come from either the L1 owner (via cross-chain message) or the L2 owner. Reverts otherwise.
   */
  modifier onlyLocalOrCrossDomainOwner() {
    address messenger = crossDomainMessenger();
    // 1. The delegatecall MUST come from either the L1 owner (via cross-chain message) or the L2 owner
    require(msg.sender == messenger || msg.sender == owner(), "Sender is not the L2 messenger or owner");
    // 2. The L2 Messenger's caller MUST be the L1 Owner
    if (msg.sender == messenger) {
      require(
        iOVM_CrossDomainMessenger(messenger).xDomainMessageSender() == l1Owner(),
        "xDomain sender is not the L1 owner"
      );
    }
    _;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title DelegateForwarderInterface - forwards a delegatecall to a target, under some conditions
interface DelegateForwarderInterface {
  /**
   * @notice forward delegatecalls the `target` with `data`
   * @param target contract address to be delegatecalled
   * @param data to send to target contract
   */
  function forwardDelegate(address target, bytes memory data) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

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
    assembly {
      size := extcodesize(account)
    }
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
pragma solidity ^0.8.0;

import "../interfaces/TypeAndVersionInterface.sol";

/* ./dev dependencies - to be moved from ./dev after audit */
import "./CrossDomainForwarder.sol";
import "./vendor/@eth-optimism/contracts/0.4.7/contracts/optimistic-ethereum/iOVM/bridge/messaging/iOVM_CrossDomainMessenger.sol";
import "./vendor/openzeppelin-solidity/v4.3.1/contracts/utils/Address.sol";

/**
 * @title OptimismCrossDomainForwarder - L1 xDomain account representation
 * @notice L2 Contract which receives messages from a specific L1 address and transparently forwards them to the destination.
 * @dev Any other L2 contract which uses this contract's address as a privileged position,
 *   can be considered to be owned by the `l1Owner`
 */
contract OptimismCrossDomainForwarder is TypeAndVersionInterface, CrossDomainForwarder {
  // OVM_L2CrossDomainMessenger is a precompile usually deployed to 0x4200000000000000000000000000000000000007
  iOVM_CrossDomainMessenger private immutable OVM_CROSS_DOMAIN_MESSENGER;

  /**
   * @notice creates a new Optimism xDomain Forwarder contract
   * @param crossDomainMessengerAddr the xDomain bridge messenger (Optimism bridge L2) contract address
   * @param l1OwnerAddr the L1 owner address that will be allowed to call the forward fn
   */
  constructor(iOVM_CrossDomainMessenger crossDomainMessengerAddr, address l1OwnerAddr) CrossDomainOwnable(l1OwnerAddr) {
    require(address(crossDomainMessengerAddr) != address(0), "Invalid xDomain Messenger address");
    OVM_CROSS_DOMAIN_MESSENGER = crossDomainMessengerAddr;
  }

  /**
   * @notice versions:
   *
   * - OptimismCrossDomainForwarder 0.1.0: initial release
   * - OptimismCrossDomainForwarder 1.0.0: Use OZ Address, CrossDomainOwnable
   *
   * @inheritdoc TypeAndVersionInterface
   */
  function typeAndVersion() external pure virtual override returns (string memory) {
    return "OptimismCrossDomainForwarder 1.0.0";
  }

  /**
   * @dev forwarded only if L2 Messenger calls with `xDomainMessageSender` being the L1 owner address
   * @inheritdoc ForwarderInterface
   */
  function forward(address target, bytes memory data) external virtual override onlyL1Owner {
    Address.functionCall(target, data, "Forwarder call reverted");
  }

  /**
   * @notice This is always the address of the OVM_L2CrossDomainMessenger contract
   */
  function crossDomainMessenger() public view returns (address) {
    return address(OVM_CROSS_DOMAIN_MESSENGER);
  }

  /**
   * @notice The call MUST come from the L1 owner (via cross-chain message.) Reverts otherwise.
   */
  modifier onlyL1Owner() override {
    require(msg.sender == crossDomainMessenger(), "Sender is not the L2 messenger");
    require(
      iOVM_CrossDomainMessenger(crossDomainMessenger()).xDomainMessageSender() == l1Owner(),
      "xDomain sender is not the L1 owner"
    );
    _;
  }

  /**
   * @notice The call MUST come from the proposed L1 owner (via cross-chain message.) Reverts otherwise.
   */
  modifier onlyProposedL1Owner() override {
    address messenger = crossDomainMessenger();
    require(msg.sender == messenger, "Sender is not the L2 messenger");
    require(
      iOVM_CrossDomainMessenger(messenger).xDomainMessageSender() == s_l1PendingOwner,
      "Must be proposed L1 owner"
    );
    _;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CrossDomainOwnable.sol";
import "./interfaces/ForwarderInterface.sol";

/**
 * @title CrossDomainForwarder - L1 xDomain account representation
 * @notice L2 Contract which receives messages from a specific L1 address and transparently forwards them to the destination.
 * @dev Any other L2 contract which uses this contract's address as a privileged position,
 *   can consider that position to be held by the `l1Owner`
 */
abstract contract CrossDomainForwarder is ForwarderInterface, CrossDomainOwnable {

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../ConfirmedOwner.sol";
import "./interfaces/CrossDomainOwnableInterface.sol";

/**
 * @title The CrossDomainOwnable contract
 * @notice A contract with helpers for cross-domain contract ownership.
 */
contract CrossDomainOwnable is CrossDomainOwnableInterface, ConfirmedOwner {
  address internal s_l1Owner;
  address internal s_l1PendingOwner;

  constructor(address newl1Owner) ConfirmedOwner(msg.sender) {
    _setL1Owner(newl1Owner);
  }

  /**
   * @notice transfer ownership of this account to a new L1 owner
   * @param to new L1 owner that will be allowed to call the forward fn
   */
  function transferL1Ownership(address to) public virtual override onlyL1Owner {
    _transferL1Ownership(to);
  }

  /**
   * @notice accept ownership of this account to a new L1 owner
   */
  function acceptL1Ownership() public virtual override onlyProposedL1Owner {
    _setL1Owner(s_l1PendingOwner);
  }

  /**
   * @notice Get the current owner
   */
  function l1Owner() public view override returns (address) {
    return s_l1Owner;
  }

  /**
   * @notice validate, transfer ownership, and emit relevant events
   */
  function _transferL1Ownership(address to) internal {
    require(to != msg.sender, "Cannot transfer to self");

    s_l1PendingOwner = to;

    emit L1OwnershipTransferRequested(s_l1Owner, to);
  }

  /**
   * @notice set ownership, emit relevant events. Used in acceptOwnership()
   */
  function _setL1Owner(address to) internal {
    address oldOwner = s_l1Owner;
    s_l1Owner = to;
    s_l1PendingOwner = address(0);

    emit L1OwnershipTransferred(oldOwner, to);
  }

  /**
   * @notice Reverts if called by anyone other than the L1 owner.
   */
  modifier onlyL1Owner() virtual {
    require(msg.sender == s_l1Owner, "Only callable by L1 owner");
    _;
  }

  /**
   * @notice Reverts if called by anyone other than the L1 owner.
   */
  modifier onlyProposedL1Owner() virtual {
    require(msg.sender == s_l1PendingOwner, "Only callable by proposed L1 owner");
    _;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title CrossDomainOwnableInterface - A contract with helpers for cross-domain contract ownership
interface CrossDomainOwnableInterface {
  event L1OwnershipTransferRequested(address indexed from, address indexed to);

  event L1OwnershipTransferred(address indexed from, address indexed to);

  function l1Owner() external returns (address);

  function transferL1Ownership(address recipient) external;

  function acceptL1Ownership() external;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6 <0.9.0;

import "../../dev/vendor/openzeppelin-solidity/v4.3.1/contracts/utils/Address.sol";

/**
 * @title iOVM_CrossDomainMessenger
 */
interface iOVM_CrossDomainMessenger {
  /**********
   * Events *
   **********/

  event SentMessage(bytes message);
  event RelayedMessage(bytes32 msgHash);
  event FailedRelayedMessage(bytes32 msgHash);

  /*************
   * Variables *
   *************/

  function xDomainMessageSender() external view returns (address);

  /********************
   * Public Functions *
   ********************/

  /**
   * Sends a cross domain message to the target messenger.
   * @param _target Target contract address.
   * @param _message Message to send to the target.
   * @param _gasLimit Gas limit for the provided message.
   */
  function sendMessage(
    address _target,
    bytes calldata _message,
    uint32 _gasLimit
  ) external;
}

contract MockOVMCrossDomainMessenger is iOVM_CrossDomainMessenger{
  address internal mockMessageSender;

  constructor(address sender) {
    mockMessageSender = sender;
  }

  function xDomainMessageSender() external view override returns (address) {
    return mockMessageSender;
  }

  function _setMockMessageSender(address sender) external {
      mockMessageSender = sender;
  }

  /********************
   * Public Functions *
   ********************/

  /**
   * Sends a cross domain message to the target messenger.
   * @param _target Target contract address.
   * @param _message Message to send to the target.
   * @param _gasLimit Gas limit for the provided message.
   */
  function sendMessage(
    address _target,
    bytes calldata _message,
    uint32 _gasLimit
  ) external override {
    Address.functionCall(_target, _message, "sendMessage reverted");
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/AggregatorValidatorInterface.sol";
import "../interfaces/TypeAndVersionInterface.sol";
import "../interfaces/AccessControllerInterface.sol";
import "../interfaces/AggregatorV3Interface.sol";
import "../SimpleWriteAccessController.sol";

/* ./dev dependencies - to be moved from ./dev after audit */
import "./interfaces/ArbitrumSequencerUptimeFeedInterface.sol";
import "./interfaces/FlagsInterface.sol";
import "./vendor/arb-bridge-eth/v0.8.0-custom/contracts/bridge/interfaces/IInbox.sol";
import "./vendor/arb-bridge-eth/v0.8.0-custom/contracts/libraries/AddressAliasHelper.sol";
import "./vendor/arb-os/e8d9696f21/contracts/arbos/builtin/ArbSys.sol";
import "./vendor/openzeppelin-solidity/v4.3.1/contracts/utils/Address.sol";

/**
 * @title ArbitrumValidator - makes xDomain L2 Flags contract call (using L2 xDomain Forwarder contract)
 * @notice Allows to raise and lower Flags on the Arbitrum L2 network through L1 bridge
 *  - The internal AccessController controls the access of the validate method
 *  - Gas configuration is controlled by a configurable external SimpleWriteAccessController
 *  - Funds on the contract are managed by the owner
 */
contract ArbitrumValidator is TypeAndVersionInterface, AggregatorValidatorInterface, SimpleWriteAccessController {
  enum PaymentStrategy {
    L1,
    L2
  }
  // Config for L1 -> L2 Arbitrum retryable ticket message
  struct GasConfig {
    uint256 maxGas;
    uint256 gasPriceBid;
    address gasPriceL1FeedAddr;
  }

  /// @dev Precompiled contract that exists in every Arbitrum chain at address(100). Exposes a variety of system-level functionality.
  address constant ARBSYS_ADDR = address(0x0000000000000000000000000000000000000064);

  int256 private constant ANSWER_SEQ_OFFLINE = 1;

  address public immutable CROSS_DOMAIN_MESSENGER;
  address public immutable L2_SEQ_STATUS_RECORDER;
  // L2 xDomain alias address of this contract
  address public immutable L2_ALIAS = AddressAliasHelper.applyL1ToL2Alias(address(this));

  PaymentStrategy private s_paymentStrategy;
  GasConfig private s_gasConfig;
  AccessControllerInterface private s_configAC;

  /**
   * @notice emitted when a new payment strategy is set
   * @param paymentStrategy strategy describing how the contract pays for xDomain calls
   */
  event PaymentStrategySet(PaymentStrategy indexed paymentStrategy);

  /**
   * @notice emitted when a new gas configuration is set
   * @param maxGas gas limit for immediate L2 execution attempt.
   * @param gasPriceBid maximum L2 gas price to pay
   * @param gasPriceL1FeedAddr address of the L1 gas price feed (used to approximate Arbitrum retryable ticket submission cost)
   */
  event GasConfigSet(uint256 maxGas, uint256 gasPriceBid, address indexed gasPriceL1FeedAddr);

  /**
   * @notice emitted when a new gas access-control contract is set
   * @param previous the address prior to the current setting
   * @param current the address of the new access-control contract
   */
  event ConfigACSet(address indexed previous, address indexed current);

  /**
   * @notice emitted when a new ETH withdrawal from L2 was requested
   * @param id unique id of the published retryable transaction (keccak256(requestID, uint(0))
   * @param amount of funds to withdraw
   */
  event L2WithdrawalRequested(uint256 indexed id, uint256 amount, address indexed refundAddr);

  /**
   * @param crossDomainMessengerAddr address the xDomain bridge messenger (Arbitrum Inbox L1) contract address
   * @param l2ArbitrumSequencerUptimeFeedAddr the L2 Flags contract address
   * @param configACAddr address of the access controller for managing gas price on Arbitrum
   * @param maxGas gas limit for immediate L2 execution attempt. A value around 1M should be sufficient
   * @param gasPriceBid maximum L2 gas price to pay
   * @param gasPriceL1FeedAddr address of the L1 gas price feed (used to approximate Arbitrum retryable ticket submission cost)
   * @param paymentStrategy strategy describing how the contract pays for xDomain calls
   */
  constructor(
    address crossDomainMessengerAddr,
    address l2ArbitrumSequencerUptimeFeedAddr,
    address configACAddr,
    uint256 maxGas,
    uint256 gasPriceBid,
    address gasPriceL1FeedAddr,
    PaymentStrategy paymentStrategy
  ) {
    require(crossDomainMessengerAddr != address(0), "Invalid xDomain Messenger address");
    require(l2ArbitrumSequencerUptimeFeedAddr != address(0), "Invalid ArbitrumSequencerUptimeFeed contract address");
    CROSS_DOMAIN_MESSENGER = crossDomainMessengerAddr;
    L2_SEQ_STATUS_RECORDER = l2ArbitrumSequencerUptimeFeedAddr;
    // Additional L2 payment configuration
    _setConfigAC(configACAddr);
    _setGasConfig(maxGas, gasPriceBid, gasPriceL1FeedAddr);
    _setPaymentStrategy(paymentStrategy);
  }

  /**
   * @notice versions:
   *
   * - ArbitrumValidator 0.1.0: initial release
   * - ArbitrumValidator 0.2.0: critical Arbitrum network update
   *   - xDomain `msg.sender` backwards incompatible change (now an alias address)
   *   - new `withdrawFundsFromL2` fn that withdraws from L2 xDomain alias address
   *   - approximation of `maxSubmissionCost` using a L1 gas price feed
   * - ArbitrumValidator 1.0.0: change target of L2 sequencer status update
   *   - now calls `updateStatus` on an L2 ArbitrumSequencerUptimeFeed contract instead of
   *     directly calling the Flags contract
   *
   * @inheritdoc TypeAndVersionInterface
   */
  function typeAndVersion() external pure virtual override returns (string memory) {
    return "ArbitrumValidator 1.0.0";
  }

  /// @return stored PaymentStrategy
  function paymentStrategy() external view virtual returns (PaymentStrategy) {
    return s_paymentStrategy;
  }

  /// @return stored GasConfig
  function gasConfig() external view virtual returns (GasConfig memory) {
    return s_gasConfig;
  }

  /// @return config AccessControllerInterface contract address
  function configAC() external view virtual returns (address) {
    return address(s_configAC);
  }

  /**
   * @notice makes this contract payable
   * @dev receives funds:
   *  - to use them (if configured) to pay for L2 execution on L1
   *  - when withdrawing funds from L2 xDomain alias address (pay for L2 execution on L2)
   */
  receive() external payable {}

  /**
   * @notice withdraws all funds available in this contract to the msg.sender
   * @dev only owner can call this
   */
  function withdrawFunds() external onlyOwner {
    address payable recipient = payable(msg.sender);
    uint256 amount = address(this).balance;
    Address.sendValue(recipient, amount);
  }

  /**
   * @notice withdraws all funds available in this contract to the address specified
   * @dev only owner can call this
   * @param recipient address where to send the funds
   */
  function withdrawFundsTo(address payable recipient) external onlyOwner {
    uint256 amount = address(this).balance;
    Address.sendValue(recipient, amount);
  }

  /**
   * @notice withdraws funds from L2 xDomain alias address (representing this L1 contract)
   * @dev only owner can call this
   * @param amount of funds to withdraws
   * @param refundAddr address where gas excess on L2 will be sent
   *   WARNING: `refundAddr` is not aliased! Make sure you can recover the refunded funds on L2.
   * @return id unique id of the published retryable transaction (keccak256(requestID, uint(0))
   */
  function withdrawFundsFromL2(uint256 amount, address refundAddr) external onlyOwner returns (uint256 id) {
    // Build an xDomain message to trigger the ArbSys precompile, which will create a L2 -> L1 tx transferring `amount`
    bytes memory message = abi.encodeWithSelector(ArbSys.withdrawEth.selector, address(this));
    // Make the xDomain call
    // NOTICE: We approximate the max submission cost of sending a retryable tx with specific calldata length.
    uint256 maxSubmissionCost = _approximateMaxSubmissionCost(message.length);
    uint256 maxGas = 120_000; // static `maxGas` for L2 -> L1 transfer
    uint256 gasPriceBid = s_gasConfig.gasPriceBid;
    uint256 l1PaymentValue = s_paymentStrategy == PaymentStrategy.L1
      ? _maxRetryableTicketCost(maxSubmissionCost, maxGas, gasPriceBid)
      : 0;
    // NOTICE: In the case of PaymentStrategy.L2 the L2 xDomain alias address needs to be funded, as it will be paying the fee.
    id = IInbox(CROSS_DOMAIN_MESSENGER).createRetryableTicketNoRefundAliasRewrite{value: l1PaymentValue}(
      ARBSYS_ADDR, // target
      amount, // L2 call value (requested)
      maxSubmissionCost,
      refundAddr, // excessFeeRefundAddress
      refundAddr, // callValueRefundAddress
      maxGas,
      gasPriceBid,
      message
    );
    emit L2WithdrawalRequested(id, amount, refundAddr);
  }

  /**
   * @notice sets config AccessControllerInterface contract
   * @dev only owner can call this
   * @param accessController new AccessControllerInterface contract address
   */
  function setConfigAC(address accessController) external onlyOwner {
    _setConfigAC(accessController);
  }

  /**
   * @notice sets Arbitrum gas configuration
   * @dev access control provided by `configAC`
   * @param maxGas gas limit for immediate L2 execution attempt. A value around 1M should be sufficient
   * @param gasPriceBid maximum L2 gas price to pay
   * @param gasPriceL1FeedAddr address of the L1 gas price feed (used to approximate Arbitrum retryable ticket submission cost)
   */
  function setGasConfig(
    uint256 maxGas,
    uint256 gasPriceBid,
    address gasPriceL1FeedAddr
  ) external onlyOwnerOrConfigAccess {
    _setGasConfig(maxGas, gasPriceBid, gasPriceL1FeedAddr);
  }

  /**
   * @notice sets the payment strategy
   * @dev access control provided by `configAC`
   * @param paymentStrategy strategy describing how the contract pays for xDomain calls
   */
  function setPaymentStrategy(PaymentStrategy paymentStrategy) external onlyOwnerOrConfigAccess {
    _setPaymentStrategy(paymentStrategy);
  }

  /**
   * @notice validate method sends an xDomain L2 tx to update Flags contract, in case of change from `previousAnswer`.
   * @dev A retryable ticket is created on the Arbitrum L1 Inbox contract. The tx gas fee can be paid from this
   *   contract providing a value, or if no L1 value is sent with the xDomain message the gas will be paid by
   *   the L2 xDomain alias account (generated from `address(this)`). This method is accessed controlled.
   * @param previousAnswer previous aggregator answer
   * @param currentAnswer new aggregator answer - value of 1 considers the service offline.
   */
  function validate(
    uint256, /* previousRoundId */
    int256 previousAnswer,
    uint256, /* currentRoundId */
    int256 currentAnswer
  ) external override checkAccess returns (bool) {
    // Avoids resending to L2 the same tx on every call
    if (previousAnswer == currentAnswer) {
      return true;
    }

    // Excess gas on L2 will be sent to the L2 xDomain alias address of this contract
    address refundAddr = L2_ALIAS;
    // Encode the ArbitrumSequencerUptimeFeed call
    bytes4 selector = ArbitrumSequencerUptimeFeedInterface.updateStatus.selector;
    bool status = currentAnswer == ANSWER_SEQ_OFFLINE;
    uint64 timestamp = uint64(block.timestamp);
    // Encode `status` and `timestamp`
    bytes memory message = abi.encodeWithSelector(selector, status, timestamp);
    // Make the xDomain call
    // NOTICE: We approximate the max submission cost of sending a retryable tx with specific calldata length.
    uint256 maxSubmissionCost = _approximateMaxSubmissionCost(message.length);
    uint256 maxGas = s_gasConfig.maxGas;
    uint256 gasPriceBid = s_gasConfig.gasPriceBid;
    uint256 l1PaymentValue = s_paymentStrategy == PaymentStrategy.L1
      ? _maxRetryableTicketCost(maxSubmissionCost, maxGas, gasPriceBid)
      : 0;
    // NOTICE: In the case of PaymentStrategy.L2 the L2 xDomain alias address needs to be funded, as it will be paying the fee.
    // We also ignore the returned msg number, that can be queried via the `InboxMessageDelivered` event.
    IInbox(CROSS_DOMAIN_MESSENGER).createRetryableTicketNoRefundAliasRewrite{value: l1PaymentValue}(
      L2_SEQ_STATUS_RECORDER, // target
      0, // L2 call value
      maxSubmissionCost,
      refundAddr, // excessFeeRefundAddress
      refundAddr, // callValueRefundAddress
      maxGas,
      gasPriceBid,
      message
    );
    // return success
    return true;
  }

  /// @notice internal method that stores the payment strategy
  function _setPaymentStrategy(PaymentStrategy paymentStrategy) internal {
    s_paymentStrategy = paymentStrategy;
    emit PaymentStrategySet(paymentStrategy);
  }

  /// @notice internal method that stores the gas configuration
  function _setGasConfig(
    uint256 maxGas,
    uint256 gasPriceBid,
    address gasPriceL1FeedAddr
  ) internal {
    require(maxGas > 0, "Max gas is zero");
    require(gasPriceBid > 0, "Gas price bid is zero");
    require(gasPriceL1FeedAddr != address(0), "Gas price Aggregator is zero address");
    s_gasConfig = GasConfig(maxGas, gasPriceBid, gasPriceL1FeedAddr);
    emit GasConfigSet(maxGas, gasPriceBid, gasPriceL1FeedAddr);
  }

  /// @notice Internal method that stores the configuration access controller
  function _setConfigAC(address accessController) internal {
    address previousAccessController = address(s_configAC);
    if (accessController != previousAccessController) {
      s_configAC = AccessControllerInterface(accessController);
      emit ConfigACSet(previousAccessController, accessController);
    }
  }

  /**
   * @notice Internal method that approximates the `maxSubmissionCost` (using the L1 gas price feed)
   * @dev On L2 this info is available via `ArbRetryableTx.getSubmissionPrice`.
   * @param calldataSizeInBytes xDomain message size in bytes
   */
  function _approximateMaxSubmissionCost(uint256 calldataSizeInBytes) internal view returns (uint256) {
    (, int256 l1GasPriceInWei, , , ) = AggregatorV3Interface(s_gasConfig.gasPriceL1FeedAddr).latestRoundData();
    uint256 l1GasPriceEstimate = uint256(l1GasPriceInWei) * 3; // add 200% buffer (price volatility error margin)
    return (l1GasPriceEstimate * calldataSizeInBytes) / 256 + l1GasPriceEstimate;
  }

  /// @notice Internal helper method that calculates the total cost of the xDomain retryable ticket call
  function _maxRetryableTicketCost(
    uint256 maxSubmissionCost,
    uint256 maxGas,
    uint256 gasPriceBid
  ) internal pure returns (uint256) {
    return maxSubmissionCost + maxGas * gasPriceBid;
  }

  /// @dev reverts if the caller does not have access to change the configuration
  modifier onlyOwnerOrConfigAccess() {
    require(
      msg.sender == owner() || (address(s_configAC) != address(0) && s_configAC.hasAccess(msg.sender, msg.data)),
      "No access"
    );
    _;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ArbitrumSequencerUptimeFeedInterface {
  function updateStatus(bool status, uint64 timestamp) external;
}

// SPDX-License-Identifier: Apache-2.0

/*
 * Copyright 2021, Offchain Labs, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// NOTICE: pragma change from original (^0.6.11)
pragma solidity ^0.8.0;

import "./IBridge.sol";
import "./IMessageProvider.sol";

interface IInbox is IMessageProvider {
  function sendL2Message(bytes calldata messageData) external returns (uint256);

  function sendUnsignedTransaction(
    uint256 maxGas,
    uint256 gasPriceBid,
    uint256 nonce,
    address destAddr,
    uint256 amount,
    bytes calldata data
  ) external returns (uint256);

  function sendContractTransaction(
    uint256 maxGas,
    uint256 gasPriceBid,
    address destAddr,
    uint256 amount,
    bytes calldata data
  ) external returns (uint256);

  function sendL1FundedUnsignedTransaction(
    uint256 maxGas,
    uint256 gasPriceBid,
    uint256 nonce,
    address destAddr,
    bytes calldata data
  ) external payable returns (uint256);

  function sendL1FundedContractTransaction(
    uint256 maxGas,
    uint256 gasPriceBid,
    address destAddr,
    bytes calldata data
  ) external payable returns (uint256);

  function createRetryableTicketNoRefundAliasRewrite(
    address destAddr,
    uint256 arbTxCallValue,
    uint256 maxSubmissionCost,
    address submissionRefundAddress,
    address valueRefundAddress,
    uint256 maxGas,
    uint256 gasPriceBid,
    bytes calldata data
  ) external payable returns (uint256);

  function createRetryableTicket(
    address destAddr,
    uint256 arbTxCallValue,
    uint256 maxSubmissionCost,
    address submissionRefundAddress,
    address valueRefundAddress,
    uint256 maxGas,
    uint256 gasPriceBid,
    bytes calldata data
  ) external payable returns (uint256);

  function depositEth(address destAddr) external payable returns (uint256);

  function depositEthRetryable(
    address destAddr,
    uint256 maxSubmissionCost,
    uint256 maxGas,
    uint256 maxGasPrice
  ) external payable returns (uint256);

  function bridge() external view returns (IBridge);
}

// SPDX-License-Identifier: Apache-2.0

/*
 * Copyright 2019-2021, Offchain Labs, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// NOTICE: pragma change from original (^0.6.11)
pragma solidity ^0.8.0;

library AddressAliasHelper {
  uint160 constant offset = uint160(0x1111000000000000000000000000000000001111);

  /// @notice Utility function that converts the msg.sender viewed in the L2 to the
  /// address in the L1 that submitted a tx to the inbox
  /// @param l1Address L2 address as viewed in msg.sender
  /// @return l2Address the address in the L1 that triggered the tx to L2
  function applyL1ToL2Alias(address l1Address) internal pure returns (address l2Address) {
    unchecked {
      l2Address = address(uint160(l1Address) + offset);
    }
  }

  /// @notice Utility function that converts the msg.sender viewed in the L2 to the
  /// address in the L1 that submitted a tx to the inbox
  /// @param l2Address L2 address as viewed in msg.sender
  /// @return l1Address the address in the L1 that triggered the tx to L2
  function undoL1ToL2Alias(address l2Address) internal pure returns (address l1Address) {
    unchecked {
      l1Address = address(uint160(l2Address) - offset);
    }
  }
}

// NOTICE: pragma change from original (>=0.4.21 <0.7.0)
pragma solidity >=0.4.21 <0.9.0;

/**
 * @title Precompiled contract that exists in every Arbitrum chain at address(100), 0x0000000000000000000000000000000000000064. Exposes a variety of system-level functionality.
 */
interface ArbSys {
  /**
   * @notice Get internal version number identifying an ArbOS build
   * @return version number as int
   */
  function arbOSVersion() external pure returns (uint256);

  function arbChainID() external view returns (uint256);

  /**
   * @notice Get Arbitrum block number (distinct from L1 block number; Arbitrum genesis block has block number 0)
   * @return block number as int
   */
  function arbBlockNumber() external view returns (uint256);

  /**
   * @notice Send given amount of Eth to dest from sender.
   * This is a convenience function, which is equivalent to calling sendTxToL1 with empty calldataForL1.
   * @param destination recipient address on L1
   * @return unique identifier for this L2-to-L1 transaction.
   */
  function withdrawEth(address destination) external payable returns (uint256);

  /**
   * @notice Send a transaction to L1
   * @param destination recipient address on L1
   * @param calldataForL1 (optional) calldata for L1 contract call
   * @return a unique identifier for this L2-to-L1 transaction.
   */
  function sendTxToL1(address destination, bytes calldata calldataForL1) external payable returns (uint256);

  /**
   * @notice get the number of transactions issued by the given external account or the account sequence number of the given contract
   * @param account target account
   * @return the number of transactions issued by the given external account or the account sequence number of the given contract
   */
  function getTransactionCount(address account) external view returns (uint256);

  /**
   * @notice get the value of target L2 storage slot
   * This function is only callable from address 0 to prevent contracts from being able to call it
   * @param account target account
   * @param index target index of storage slot
   * @return stotage value for the given account at the given index
   */
  function getStorageAt(address account, uint256 index) external view returns (uint256);

  /**
   * @notice check if current call is coming from l1
   * @return true if the caller of this was called directly from L1
   */
  function isTopLevelCall() external view returns (bool);

  event L2ToL1Transaction(
    address caller,
    address indexed destination,
    uint256 indexed uniqueId,
    uint256 indexed batchNumber,
    uint256 indexInBatch,
    uint256 arbBlockNum,
    uint256 ethBlockNum,
    uint256 timestamp,
    uint256 callvalue,
    bytes data
  );
}

// SPDX-License-Identifier: Apache-2.0

/*
 * Copyright 2021, Offchain Labs, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// NOTICE: pragma change from original (^0.6.11)
pragma solidity ^0.8.0;

interface IBridge {
  event MessageDelivered(
    uint256 indexed messageIndex,
    bytes32 indexed beforeInboxAcc,
    address inbox,
    uint8 kind,
    address sender,
    bytes32 messageDataHash
  );

  function deliverMessageToInbox(
    uint8 kind,
    address sender,
    bytes32 messageDataHash
  ) external payable returns (uint256);

  function executeCall(
    address destAddr,
    uint256 amount,
    bytes calldata data
  ) external returns (bool success, bytes memory returnData);

  // These are only callable by the admin
  function setInbox(address inbox, bool enabled) external;

  function setOutbox(address inbox, bool enabled) external;

  // View functions

  function activeOutbox() external view returns (address);

  function allowedInboxes(address inbox) external view returns (bool);

  function allowedOutboxes(address outbox) external view returns (bool);

  function inboxAccs(uint256 index) external view returns (bytes32);

  function messageCount() external view returns (uint256);
}

// SPDX-License-Identifier: Apache-2.0

/*
 * Copyright 2021, Offchain Labs, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// NOTICE: pragma change from original (^0.6.11)
pragma solidity ^0.8.0;

interface IMessageProvider {
  event InboxMessageDelivered(uint256 indexed messageNum, bytes data);

  event InboxMessageDeliveredFromOrigin(uint256 indexed messageNum);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {AddressAliasHelper} from "./vendor/arb-bridge-eth/v0.8.0-custom/contracts/libraries/AddressAliasHelper.sol";
import {ForwarderInterface} from "./interfaces/ForwarderInterface.sol";
import {AggregatorInterface} from "../interfaces/AggregatorInterface.sol";
import {AggregatorV3Interface} from "../interfaces/AggregatorV3Interface.sol";
import {AggregatorV2V3Interface} from "../interfaces/AggregatorV2V3Interface.sol";
import {TypeAndVersionInterface} from "../interfaces/TypeAndVersionInterface.sol";
import {FlagsInterface} from "./interfaces/FlagsInterface.sol";
import {ArbitrumSequencerUptimeFeedInterface} from "./interfaces/ArbitrumSequencerUptimeFeedInterface.sol";
import {SimpleReadAccessController} from "../SimpleReadAccessController.sol";
import {ConfirmedOwner} from "../ConfirmedOwner.sol";

/**
 * @title ArbitrumSequencerUptimeFeed - L2 sequencer uptime status aggregator
 * @notice L2 contract that receives status updates from a specific L1 address,
 *  records a new answer if the status changed, and raises or lowers the flag on the
 *   stored Flags contract.
 */
contract ArbitrumSequencerUptimeFeed is
  AggregatorV2V3Interface,
  ArbitrumSequencerUptimeFeedInterface,
  TypeAndVersionInterface,
  SimpleReadAccessController
{
  /// @dev Round info (for uptime history)
  struct Round {
    bool status;
    uint64 timestamp;
  }

  /// @dev Packed state struct to save sloads
  struct FeedState {
    uint80 latestRoundId;
    bool latestStatus;
    uint64 latestTimestamp;
  }

  /// @notice Contract is not yet initialized
  error Uninitialized();
  /// @notice Contract is already initialized
  error AlreadyInitialized();
  /// @notice Sender is not the L2 messenger
  error InvalidSender();
  /// @notice Replacement for AggregatorV3Interface "No data present"
  error NoDataPresent();

  event Initialized();
  event L1SenderTransferred(address indexed from, address indexed to);
  /// @dev Emitted when an `updateStatus` call is ignored due to unchanged status or stale timestamp
  event UpdateIgnored(bool latestStatus, uint64 latestTimestamp, bool incomingStatus, uint64 incomingTimestamp);

  /// @dev Follows: https://eips.ethereum.org/EIPS/eip-1967
  address public constant FLAG_L2_SEQ_OFFLINE =
    address(bytes20(bytes32(uint256(keccak256("chainlink.flags.l2-seq-offline")) - 1)));

  uint8 public constant override decimals = 0;
  string public constant override description = "L2 Sequencer Uptime Status Feed";
  uint256 public constant override version = 1;

  /// @dev Flags contract to raise/lower flags on, during status transitions
  FlagsInterface public immutable FLAGS;
  /// @dev L1 address
  address private s_l1Sender;
  /// @dev s_latestRoundId == 0 means this contract is uninitialized.
  FeedState private s_feedState = FeedState({latestRoundId: 0, latestStatus: false, latestTimestamp: 0});
  mapping(uint80 => Round) private s_rounds;

  /**
   * @param flagsAddress Address of the Flags contract on L2
   * @param l1SenderAddress Address of the L1 contract that is permissioned to call this contract
   */
  constructor(address flagsAddress, address l1SenderAddress) {
    setL1Sender(l1SenderAddress);

    FLAGS = FlagsInterface(flagsAddress);
  }

  /**
   * @notice Check if a roundId is valid in this current contract state
   * @dev Mainly used for AggregatorV2V3Interface functions
   * @param roundId Round ID to check
   */
  function isValidRound(uint256 roundId) private view returns (bool) {
    return roundId > 0 && roundId <= type(uint80).max && s_feedState.latestRoundId >= roundId;
  }

  /// @notice Check that this contract is initialised, otherwise throw
  function requireInitialized(uint80 latestRoundId) private pure {
    if (latestRoundId == 0) {
      revert Uninitialized();
    }
  }

  /**
   * @notice Initialise the first round. Can't be done in the constructor,
   *    because this contract's address must be permissioned by the the Flags contract
   *    (The Flags contract itself is a SimpleReadAccessController).
   */
  function initialize() external onlyOwner {
    FeedState memory feedState = s_feedState;
    if (feedState.latestRoundId != 0) {
      revert AlreadyInitialized();
    }

    uint64 timestamp = uint64(block.timestamp);
    bool currentStatus = FLAGS.getFlag(FLAG_L2_SEQ_OFFLINE);

    // Initialise roundId == 1 as the first round
    recordRound(1, currentStatus, timestamp);

    emit Initialized();
  }

  /**
   * @notice versions:
   *
   * - ArbitrumSequencerUptimeFeed 1.0.0: initial release
   *
   * @inheritdoc TypeAndVersionInterface
   */
  function typeAndVersion() external pure virtual override returns (string memory) {
    return "ArbitrumSequencerUptimeFeed 1.0.0";
  }

  /// @return L1 sender address
  function l1Sender() public view virtual returns (address) {
    return s_l1Sender;
  }

  /**
   * @notice Set the allowed L1 sender for this contract to a new L1 sender
   * @dev Can be disabled by setting the L1 sender as `address(0)`. Accessible only by owner.
   * @param to new L1 sender that will be allowed to call `updateStatus` on this contract
   */
  function transferL1Sender(address to) external virtual onlyOwner {
    setL1Sender(to);
  }

  /// @notice internal method that stores the L1 sender
  function setL1Sender(address to) private {
    address from = s_l1Sender;
    if (from != to) {
      s_l1Sender = to;
      emit L1SenderTransferred(from, to);
    }
  }

  /**
   * @notice Messages sent by the stored L1 sender will arrive on L2 with this
   *  address as the `msg.sender`
   * @return L2-aliased form of the L1 sender address
   */
  function aliasedL1MessageSender() public view returns (address) {
    return AddressAliasHelper.applyL1ToL2Alias(l1Sender());
  }

  /**
   * @dev Returns an AggregatorV2V3Interface compatible answer from status flag
   *
   * @param status The status flag to convert to an aggregator-compatible answer
   */
  function getStatusAnswer(bool status) private pure returns (int256) {
    return status ? int256(1) : int256(0);
  }

  /**
   * @notice Raise or lower the flag on the stored Flags contract.
   */
  function forwardStatusToFlags(bool status) private {
    if (status) {
      FLAGS.raiseFlag(FLAG_L2_SEQ_OFFLINE);
    } else {
      FLAGS.lowerFlag(FLAG_L2_SEQ_OFFLINE);
    }
  }

  /**
   * @notice Helper function to record a round and set the latest feed state.
   *
   * @param roundId The round ID to record
   * @param status Sequencer status
   * @param timestamp Block timestamp of status update
   */
  function recordRound(
    uint80 roundId,
    bool status,
    uint64 timestamp
  ) private {
    Round memory nextRound = Round(status, timestamp);
    FeedState memory feedState = FeedState(roundId, status, timestamp);

    s_rounds[roundId] = nextRound;
    s_feedState = feedState;

    emit NewRound(roundId, msg.sender, timestamp);
    emit AnswerUpdated(getStatusAnswer(status), roundId, timestamp);
  }

  /**
   * @notice Record a new status and timestamp if it has changed since the last round.
   * @dev This function will revert if not called from `l1Sender` via the L1->L2 messenger.
   *
   * @param status Sequencer status
   * @param timestamp Block timestamp of status update
   */
  function updateStatus(bool status, uint64 timestamp) external override {
    FeedState memory feedState = s_feedState;
    requireInitialized(feedState.latestRoundId);
    if (msg.sender != aliasedL1MessageSender()) {
      revert InvalidSender();
    }

    // Ignore if status did not change or latest recorded timestamp is newer
    if (feedState.latestStatus == status || feedState.latestTimestamp > timestamp) {
      emit UpdateIgnored(feedState.latestStatus, feedState.latestTimestamp, status, timestamp);
      return;
    }

    // Prepare a new round with updated status
    feedState.latestRoundId += 1;
    recordRound(feedState.latestRoundId, status, timestamp);

    forwardStatusToFlags(status);
  }

  /// @inheritdoc AggregatorInterface
  function latestAnswer() external view override checkAccess returns (int256) {
    FeedState memory feedState = s_feedState;
    requireInitialized(feedState.latestRoundId);
    return getStatusAnswer(feedState.latestStatus);
  }

  /// @inheritdoc AggregatorInterface
  function latestTimestamp() external view override checkAccess returns (uint256) {
    FeedState memory feedState = s_feedState;
    requireInitialized(feedState.latestRoundId);
    return feedState.latestTimestamp;
  }

  /// @inheritdoc AggregatorInterface
  function latestRound() external view override checkAccess returns (uint256) {
    FeedState memory feedState = s_feedState;
    requireInitialized(feedState.latestRoundId);
    return feedState.latestRoundId;
  }

  /// @inheritdoc AggregatorInterface
  function getAnswer(uint256 roundId) external view override checkAccess returns (int256) {
    requireInitialized(s_feedState.latestRoundId);
    if (isValidRound(roundId)) {
      return getStatusAnswer(s_rounds[uint80(roundId)].status);
    }

    return 0;
  }

  /// @inheritdoc AggregatorInterface
  function getTimestamp(uint256 roundId) external view override checkAccess returns (uint256) {
    requireInitialized(s_feedState.latestRoundId);
    if (isValidRound(roundId)) {
      return s_rounds[uint80(roundId)].timestamp;
    }

    return 0;
  }

  /// @inheritdoc AggregatorV3Interface
  function getRoundData(uint80 _roundId)
    public
    view
    override
    checkAccess
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    )
  {
    requireInitialized(s_feedState.latestRoundId);

    if (isValidRound(_roundId)) {
      Round memory round = s_rounds[_roundId];
      answer = getStatusAnswer(round.status);
      startedAt = uint256(round.timestamp);
    } else {
      answer = 0;
      startedAt = 0;
    }
    roundId = _roundId;
    updatedAt = startedAt;
    answeredInRound = roundId;
  }

  /// @inheritdoc AggregatorV3Interface
  function latestRoundData()
    external
    view
    override
    checkAccess
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    )
  {
    FeedState memory feedState = s_feedState;
    requireInitialized(feedState.latestRoundId);

    roundId = feedState.latestRoundId;
    answer = getStatusAnswer(feedState.latestStatus);
    startedAt = feedState.latestTimestamp;
    updatedAt = startedAt;
    answeredInRound = roundId;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface AggregatorInterface {
  function latestAnswer() external view returns (int256);

  function latestTimestamp() external view returns (uint256);

  function latestRound() external view returns (uint256);

  function getAnswer(uint256 roundId) external view returns (int256);

  function getTimestamp(uint256 roundId) external view returns (uint256);

  event AnswerUpdated(int256 indexed current, uint256 indexed roundId, uint256 updatedAt);

  event NewRound(uint256 indexed roundId, address indexed startedBy, uint256 startedAt);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./AggregatorInterface.sol";
import "./AggregatorV3Interface.sol";

interface AggregatorV2V3Interface is AggregatorInterface, AggregatorV3Interface {}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SimpleWriteAccessController.sol";

/**
 * @title SimpleReadAccessController
 * @notice Gives access to:
 * - any externally owned account (note that off-chain actors can always read
 * any contract storage regardless of on-chain access control measures, so this
 * does not weaken the access control while improving usability)
 * - accounts explicitly added to an access list
 * @dev SimpleReadAccessController is not suitable for access controlling writes
 * since it grants any externally owned account access! See
 * SimpleWriteAccessController for that.
 */
contract SimpleReadAccessController is SimpleWriteAccessController {
  /**
   * @notice Returns the access of an address
   * @param _user The address to query
   */
  function hasAccess(address _user, bytes memory _calldata) public view virtual override returns (bool) {
    return super.hasAccess(_user, _calldata) || _user == tx.origin;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SimpleReadAccessController.sol";
import "./interfaces/AccessControllerInterface.sol";
import "./interfaces/FlagsInterface.sol";

/**
 * @title The Flags contract
 * @notice Allows flags to signal to any reader on the access control list.
 * The owner can set flags, or designate other addresses to set flags. The
 * owner must turn the flags off, other setters cannot. An expected pattern is
 * to allow addresses to raise flags on themselves, so if you are subscribing to
 * FlagOn events you should filter for addresses you care about.
 */
contract Flags is FlagsInterface, SimpleReadAccessController {
  AccessControllerInterface public raisingAccessController;

  mapping(address => bool) private flags;

  event FlagRaised(address indexed subject);
  event FlagLowered(address indexed subject);
  event RaisingAccessControllerUpdated(address indexed previous, address indexed current);

  /**
   * @param racAddress address for the raising access controller.
   */
  constructor(address racAddress) {
    setRaisingAccessController(racAddress);
  }

  /**
   * @notice read the warning flag status of a contract address.
   * @param subject The contract address being checked for a flag.
   * @return A true value indicates that a flag was raised and a
   * false value indicates that no flag was raised.
   */
  function getFlag(address subject) external view override checkAccess returns (bool) {
    return flags[subject];
  }

  /**
   * @notice read the warning flag status of a contract address.
   * @param subjects An array of addresses being checked for a flag.
   * @return An array of bools where a true value for any flag indicates that
   * a flag was raised and a false value indicates that no flag was raised.
   */
  function getFlags(address[] calldata subjects) external view override checkAccess returns (bool[] memory) {
    bool[] memory responses = new bool[](subjects.length);
    for (uint256 i = 0; i < subjects.length; i++) {
      responses[i] = flags[subjects[i]];
    }
    return responses;
  }

  /**
   * @notice enable the warning flag for an address.
   * Access is controlled by raisingAccessController, except for owner
   * who always has access.
   * @param subject The contract address whose flag is being raised
   */
  function raiseFlag(address subject) external override {
    require(allowedToRaiseFlags(), "Not allowed to raise flags");

    tryToRaiseFlag(subject);
  }

  /**
   * @notice enable the warning flags for multiple addresses.
   * Access is controlled by raisingAccessController, except for owner
   * who always has access.
   * @param subjects List of the contract addresses whose flag is being raised
   */
  function raiseFlags(address[] calldata subjects) external override {
    require(allowedToRaiseFlags(), "Not allowed to raise flags");

    for (uint256 i = 0; i < subjects.length; i++) {
      tryToRaiseFlag(subjects[i]);
    }
  }

  /**
   * @notice allows owner to disable the warning flags for multiple addresses.
   * @param subjects List of the contract addresses whose flag is being lowered
   */
  function lowerFlags(address[] calldata subjects) external override onlyOwner {
    for (uint256 i = 0; i < subjects.length; i++) {
      address subject = subjects[i];

      if (flags[subject]) {
        flags[subject] = false;
        emit FlagLowered(subject);
      }
    }
  }

  /**
   * @notice allows owner to change the access controller for raising flags.
   * @param racAddress new address for the raising access controller.
   */
  function setRaisingAccessController(address racAddress) public override onlyOwner {
    address previous = address(raisingAccessController);

    if (previous != racAddress) {
      raisingAccessController = AccessControllerInterface(racAddress);

      emit RaisingAccessControllerUpdated(previous, racAddress);
    }
  }

  // PRIVATE

  function allowedToRaiseFlags() private view returns (bool) {
    return msg.sender == owner() || raisingAccessController.hasAccess(msg.sender, msg.data);
  }

  function tryToRaiseFlag(address subject) private {
    if (!flags[subject]) {
      flags[subject] = true;
      emit FlagRaised(subject);
    }
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface FlagsInterface {
  function getFlag(address) external view returns (bool);

  function getFlags(address[] calldata) external view returns (bool[] memory);

  function raiseFlag(address) external;

  function raiseFlags(address[] calldata) external;

  function lowerFlags(address[] calldata) external;

  function setRaisingAccessController(address) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../Flags.sol";

contract FlagsTestHelper {
  Flags public flags;

  constructor(address flagsContract) {
    flags = Flags(flagsContract);
  }

  function getFlag(address subject) external view returns (bool) {
    return flags.getFlag(subject);
  }

  function getFlags(address[] calldata subjects) external view returns (bool[] memory) {
    return flags.getFlags(subjects);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "../SimpleReadAccessController.sol";
import "../interfaces/AccessControllerInterface.sol";
import "../interfaces/TypeAndVersionInterface.sol";

/* dev dependencies - to be re/moved after audit */
import "./interfaces/FlagsInterface.sol";

/**
 * @title The Flags contract
 * @notice Allows flags to signal to any reader on the access control list.
 * The owner can set flags, or designate other addresses to set flags.
 * Raise flag actions are controlled by its own access controller.
 * Lower flag actions are controlled by its own access controller.
 * An expected pattern is to allow addresses to raise flags on themselves, so if you are subscribing to
 * FlagOn events you should filter for addresses you care about.
 */
contract Flags is TypeAndVersionInterface, FlagsInterface, SimpleReadAccessController {
  AccessControllerInterface public raisingAccessController;
  AccessControllerInterface public loweringAccessController;

  mapping(address => bool) private flags;

  event FlagRaised(address indexed subject);
  event FlagLowered(address indexed subject);
  event RaisingAccessControllerUpdated(address indexed previous, address indexed current);
  event LoweringAccessControllerUpdated(address indexed previous, address indexed current);

  /**
   * @param racAddress address for the raising access controller.
   * @param lacAddress address for the lowering access controller.
   */
  constructor(address racAddress, address lacAddress) {
    setRaisingAccessController(racAddress);
    setLoweringAccessController(lacAddress);
  }

  /**
   * @notice versions:
   *
   * - Flags 1.1.0: upgraded to solc 0.8, added lowering access controller
   * - Flags 1.0.0: initial release
   *
   * @inheritdoc TypeAndVersionInterface
   */
  function typeAndVersion() external pure virtual override returns (string memory) {
    return "Flags 1.1.0";
  }

  /**
   * @notice read the warning flag status of a contract address.
   * @param subject The contract address being checked for a flag.
   * @return A true value indicates that a flag was raised and a
   * false value indicates that no flag was raised.
   */
  function getFlag(address subject) external view override checkAccess returns (bool) {
    return flags[subject];
  }

  /**
   * @notice read the warning flag status of a contract address.
   * @param subjects An array of addresses being checked for a flag.
   * @return An array of bools where a true value for any flag indicates that
   * a flag was raised and a false value indicates that no flag was raised.
   */
  function getFlags(address[] calldata subjects) external view override checkAccess returns (bool[] memory) {
    bool[] memory responses = new bool[](subjects.length);
    for (uint256 i = 0; i < subjects.length; i++) {
      responses[i] = flags[subjects[i]];
    }
    return responses;
  }

  /**
   * @notice enable the warning flag for an address.
   * Access is controlled by raisingAccessController, except for owner
   * who always has access.
   * @param subject The contract address whose flag is being raised
   */
  function raiseFlag(address subject) external override {
    require(_allowedToRaiseFlags(), "Not allowed to raise flags");

    _tryToRaiseFlag(subject);
  }

  /**
   * @notice enable the warning flags for multiple addresses.
   * Access is controlled by raisingAccessController, except for owner
   * who always has access.
   * @param subjects List of the contract addresses whose flag is being raised
   */
  function raiseFlags(address[] calldata subjects) external override {
    require(_allowedToRaiseFlags(), "Not allowed to raise flags");

    for (uint256 i = 0; i < subjects.length; i++) {
      _tryToRaiseFlag(subjects[i]);
    }
  }

  /**
   * @notice allows owner to disable the warning flags for an addresses.
   * Access is controlled by loweringAccessController, except for owner
   * who always has access.
   * @param subject The contract address whose flag is being lowered
   */
  function lowerFlag(address subject) external override {
    require(_allowedToLowerFlags(), "Not allowed to lower flags");

    _tryToLowerFlag(subject);
  }

  /**
   * @notice allows owner to disable the warning flags for multiple addresses.
   * Access is controlled by loweringAccessController, except for owner
   * who always has access.
   * @param subjects List of the contract addresses whose flag is being lowered
   */
  function lowerFlags(address[] calldata subjects) external override {
    require(_allowedToLowerFlags(), "Not allowed to lower flags");

    for (uint256 i = 0; i < subjects.length; i++) {
      address subject = subjects[i];

      _tryToLowerFlag(subject);
    }
  }

  /**
   * @notice allows owner to change the access controller for raising flags.
   * @param racAddress new address for the raising access controller.
   */
  function setRaisingAccessController(address racAddress) public override onlyOwner {
    address previous = address(raisingAccessController);

    if (previous != racAddress) {
      raisingAccessController = AccessControllerInterface(racAddress);

      emit RaisingAccessControllerUpdated(previous, racAddress);
    }
  }

  function setLoweringAccessController(address lacAddress) public override onlyOwner {
    address previous = address(loweringAccessController);

    if (previous != lacAddress) {
      loweringAccessController = AccessControllerInterface(lacAddress);

      emit LoweringAccessControllerUpdated(previous, lacAddress);
    }
  }

  // PRIVATE
  function _allowedToRaiseFlags() private view returns (bool) {
    return msg.sender == owner() || raisingAccessController.hasAccess(msg.sender, msg.data);
  }

  function _allowedToLowerFlags() private view returns (bool) {
    return msg.sender == owner() || loweringAccessController.hasAccess(msg.sender, msg.data);
  }

  function _tryToRaiseFlag(address subject) private {
    if (!flags[subject]) {
      flags[subject] = true;
      emit FlagRaised(subject);
    }
  }

  function _tryToLowerFlag(address subject) private {
    if (flags[subject]) {
      flags[subject] = false;
      emit FlagLowered(subject);
    }
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AggregatorV2V3Interface} from "../interfaces/AggregatorV2V3Interface.sol";

contract FeedConsumer {
  AggregatorV2V3Interface public immutable AGGREGATOR;

  constructor(address feedAddress) {
    AGGREGATOR = AggregatorV2V3Interface(feedAddress);
  }

  function latestAnswer() external view returns (int256 answer) {
    return AGGREGATOR.latestAnswer();
  }

  function latestTimestamp() external view returns (uint256) {
    return AGGREGATOR.latestTimestamp();
  }

  function latestRound() external view returns (uint256) {
    return AGGREGATOR.latestRound();
  }

  function getAnswer(uint256 roundId) external view returns (int256) {
    return AGGREGATOR.getAnswer(roundId);
  }

  function getTimestamp(uint256 roundId) external view returns (uint256) {
    return AGGREGATOR.getTimestamp(roundId);
  }

  function decimals() external view returns (uint8) {
    return AGGREGATOR.decimals();
  }

  function description() external view returns (string memory) {
    return AGGREGATOR.description();
  }

  function version() external view returns (uint256) {
    return AGGREGATOR.version();
  }

  function getRoundData(uint80 _roundId)
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    )
  {
    return AGGREGATOR.getRoundData(_roundId);
  }

  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    )
  {
    return AGGREGATOR.latestRoundData();
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import "./AggregatorV2V3Interface.sol";

interface FeedRegistryInterface {
  struct Phase {
    uint16 phaseId;
    uint80 startingAggregatorRoundId;
    uint80 endingAggregatorRoundId;
  }

  event FeedProposed(
    address indexed asset,
    address indexed denomination,
    address indexed proposedAggregator,
    address currentAggregator,
    address sender
  );
  event FeedConfirmed(
    address indexed asset,
    address indexed denomination,
    address indexed latestAggregator,
    address previousAggregator,
    uint16 nextPhaseId,
    address sender
  );

  // V3 AggregatorV3Interface

  function decimals(address base, address quote) external view returns (uint8);

  function description(address base, address quote) external view returns (string memory);

  function version(address base, address quote) external view returns (uint256);

  function latestRoundData(address base, address quote)
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

  function getRoundData(
    address base,
    address quote,
    uint80 _roundId
  )
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

  // V2 AggregatorInterface

  function latestAnswer(address base, address quote) external view returns (int256 answer);

  function latestTimestamp(address base, address quote) external view returns (uint256 timestamp);

  function latestRound(address base, address quote) external view returns (uint256 roundId);

  function getAnswer(
    address base,
    address quote,
    uint256 roundId
  ) external view returns (int256 answer);

  function getTimestamp(
    address base,
    address quote,
    uint256 roundId
  ) external view returns (uint256 timestamp);

  // Registry getters

  function getFeed(address base, address quote) external view returns (AggregatorV2V3Interface aggregator);

  function getPhaseFeed(
    address base,
    address quote,
    uint16 phaseId
  ) external view returns (AggregatorV2V3Interface aggregator);

  function isFeedEnabled(address aggregator) external view returns (bool);

  function getPhase(
    address base,
    address quote,
    uint16 phaseId
  ) external view returns (Phase memory phase);

  // Round helpers

  function getRoundFeed(
    address base,
    address quote,
    uint80 roundId
  ) external view returns (AggregatorV2V3Interface aggregator);

  function getPhaseRange(
    address base,
    address quote,
    uint16 phaseId
  ) external view returns (uint80 startingRoundId, uint80 endingRoundId);

  function getPreviousRoundId(
    address base,
    address quote,
    uint80 roundId
  ) external view returns (uint80 previousRoundId);

  function getNextRoundId(
    address base,
    address quote,
    uint80 roundId
  ) external view returns (uint80 nextRoundId);

  // Feed management

  function proposeFeed(
    address base,
    address quote,
    address aggregator
  ) external;

  function confirmFeed(
    address base,
    address quote,
    address aggregator
  ) external;

  // Proposed aggregator

  function getProposedFeed(address base, address quote)
    external
    view
    returns (AggregatorV2V3Interface proposedAggregator);

  function proposedGetRoundData(
    address base,
    address quote,
    uint80 roundId
  )
    external
    view
    returns (
      uint80 id,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

  function proposedLatestRoundData(address base, address quote)
    external
    view
    returns (
      uint80 id,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

  // Phases
  function getCurrentPhaseId(address base, address quote) external view returns (uint16 currentPhaseId);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "../interfaces/AggregatorV3Interface.sol";

/**
 * Network: Fantom Testnet
 * Base: LINK/USD
 * Base Address: 0x6d5689Ad4C1806D1BA0c70Ab95ebe0Da6B204fC5
 * Quote: FTM/USD
 * Quote Address: 0xe04676B9A9A2973BCb0D1478b5E1E9098BBB7f3D
 * Decimals: 18
 *
 * Network: AVAX Testnet
 * Base: LINK/USD
 * Base Address: 0x34C4c526902d88a3Aa98DB8a9b802603EB1E3470
 * Quote: AVAX/USD
 * Quote Address: 0x5498BB86BC934c8D34FDA08E81D444153d0D06aD
 * Decimals: 18
 *
 * Chainlink Data Feeds can be used in combination to derive denominated price pairs in other
 * currencies.
 *
 * If you require a denomination other than what is provided, you can use two data feeds to derive
 * the pair that you need.
 *
 * For example, if you needed a LINK / FTM price, you could take the LINK / USD feed and the
 * FTM / USD feed and derive LINK / FTM using division.
 * (LINK/USD)/(FTM/USD) = LINK/FTM
 */
contract DerivedPriceFeed is AggregatorV3Interface {
  uint256 public constant override version = 0;

  AggregatorV3Interface public immutable BASE;
  AggregatorV3Interface public immutable QUOTE;
  uint8 public immutable DECIMALS;

  constructor(
    address _base,
    address _quote,
    uint8 _decimals
  ) {
    require(_decimals > uint8(0) && _decimals <= uint8(18), "Invalid _decimals");
    DECIMALS = _decimals;
    BASE = AggregatorV3Interface(_base);
    QUOTE = AggregatorV3Interface(_quote);
  }

  function decimals() external view override returns (uint8) {
    return DECIMALS;
  }

  function getRoundData(uint80)
    external
    pure
    override
    returns (
      uint80,
      int256,
      uint256,
      uint256,
      uint80
    )
  {
    revert("not implemented - use latestRoundData()");
  }

  function description() external pure override returns (string memory) {
    return "DerivedPriceFeed.sol";
  }

  function latestRoundData()
    external
    view
    override
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    )
  {
    return (uint80(0), getDerivedPrice(), block.timestamp, block.timestamp, uint80(0));
  }

  // https://docs.chain.link/docs/get-the-latest-price/#getting-a-different-price-denomination
  function getDerivedPrice() internal view returns (int256) {
    (, int256 basePrice, , , ) = BASE.latestRoundData();
    uint8 baseDecimals = BASE.decimals();
    basePrice = scalePrice(basePrice, baseDecimals, DECIMALS);

    (, int256 quotePrice, , , ) = QUOTE.latestRoundData();
    uint8 quoteDecimals = QUOTE.decimals();
    quotePrice = scalePrice(quotePrice, quoteDecimals, DECIMALS);

    return (basePrice * int256(10**uint256(DECIMALS))) / quotePrice;
  }

  function scalePrice(
    int256 _price,
    uint8 _priceDecimals,
    uint8 _decimals
  ) internal pure returns (int256) {
    if (_priceDecimals < _decimals) {
      return _price * int256(10**uint256(_decimals - _priceDecimals));
    } else if (_priceDecimals > _decimals) {
      return _price / int256(10**uint256(_priceDecimals - _decimals));
    }
    return _price;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CrossDomainForwarder.sol";
import "./interfaces/ForwarderInterface.sol";
import "./interfaces/DelegateForwarderInterface.sol";

/**
 * @title CrossDomainDelegateForwarder - L1 xDomain account representation (with delegatecall support)
 * @notice L2 Contract which receives messages from a specific L1 address and transparently forwards them to the destination.
 * @dev Any other L2 contract which uses this contract's address as a privileged position,
 *   can consider that position to be held by the `l1Owner`
 */
abstract contract CrossDomainDelegateForwarder is DelegateForwarderInterface, CrossDomainOwnable {

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/DelegateForwarderInterface.sol";
import "./vendor/arb-bridge-eth/v0.8.0-custom/contracts/libraries/AddressAliasHelper.sol";
import "./vendor/openzeppelin-solidity/v4.3.1/contracts/utils/Address.sol";
import "./ArbitrumCrossDomainForwarder.sol";

/**
 * @title ArbitrumCrossDomainGovernor - L1 xDomain account representation (with delegatecall support) for Arbitrum
 * @notice L2 Contract which receives messages from a specific L1 address and transparently forwards them to the destination.
 * @dev Any other L2 contract which uses this contract's address as a privileged position,
 *   can be considered to be simultaneously owned by the `l1Owner` and L2 `owner`
 */
contract ArbitrumCrossDomainGovernor is DelegateForwarderInterface, ArbitrumCrossDomainForwarder {
  /**
   * @notice creates a new Arbitrum xDomain Forwarder contract
   * @param l1OwnerAddr the L1 owner address that will be allowed to call the forward fn
   * @dev Empty constructor required due to inheriting from abstract contract CrossDomainForwarder
   */
  constructor(address l1OwnerAddr) ArbitrumCrossDomainForwarder(l1OwnerAddr) {}

  /**
   * @notice versions:
   *
   * - ArbitrumCrossDomainGovernor 1.0.0: initial release
   *
   * @inheritdoc TypeAndVersionInterface
   */
  function typeAndVersion() external pure virtual override returns (string memory) {
    return "ArbitrumCrossDomainGovernor 1.0.0";
  }

  /**
   * @dev forwarded only if L2 Messenger calls with `msg.sender` being the L1 owner address, or called by the L2 owner
   * @inheritdoc ForwarderInterface
   */
  function forward(address target, bytes memory data) external override onlyLocalOrCrossDomainOwner {
    Address.functionCall(target, data, "Governor call reverted");
  }

  /**
   * @dev forwarded only if L2 Messenger calls with `msg.sender` being the L1 owner address, or called by the L2 owner
   * @inheritdoc DelegateForwarderInterface
   */
  function forwardDelegate(address target, bytes memory data) external override onlyLocalOrCrossDomainOwner {
    Address.functionDelegateCall(target, data, "Governor delegatecall reverted");
  }

  /**
   * @notice The call MUST come from either the L1 owner (via cross-chain message) or the L2 owner. Reverts otherwise.
   */
  modifier onlyLocalOrCrossDomainOwner() {
    require(msg.sender == crossDomainMessenger() || msg.sender == owner(), "Sender is not the L2 messenger or owner");
    _;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/TypeAndVersionInterface.sol";
import "./vendor/arb-bridge-eth/v0.8.0-custom/contracts/libraries/AddressAliasHelper.sol";
import "./vendor/openzeppelin-solidity/v4.3.1/contracts/utils/Address.sol";
import "./CrossDomainForwarder.sol";

/**
 * @title ArbitrumCrossDomainForwarder - L1 xDomain account representation
 * @notice L2 Contract which receives messages from a specific L1 address and transparently forwards them to the destination.
 * @dev Any other L2 contract which uses this contract's address as a privileged position,
 *   can be considered to be owned by the `l1Owner`
 */
contract ArbitrumCrossDomainForwarder is TypeAndVersionInterface, CrossDomainForwarder {
  /**
   * @notice creates a new Arbitrum xDomain Forwarder contract
   * @param l1OwnerAddr the L1 owner address that will be allowed to call the forward fn
   * @dev Empty constructor required due to inheriting from abstract contract CrossDomainForwarder
   */
  constructor(address l1OwnerAddr) CrossDomainOwnable(l1OwnerAddr) {}

  /**
   * @notice versions:
   *
   * - ArbitrumCrossDomainForwarder 0.1.0: initial release
   * - ArbitrumCrossDomainForwarder 1.0.0: Use OZ Address, CrossDomainOwnable
   *
   * @inheritdoc TypeAndVersionInterface
   */
  function typeAndVersion() external pure virtual override returns (string memory) {
    return "ArbitrumCrossDomainForwarder 1.0.0";
  }

  /**
   * @notice The L2 xDomain `msg.sender`, generated from L1 sender address
   */
  function crossDomainMessenger() public view returns (address) {
    return AddressAliasHelper.applyL1ToL2Alias(l1Owner());
  }

  /**
   * @dev forwarded only if L2 Messenger calls with `xDomainMessageSender` being the L1 owner address
   * @inheritdoc ForwarderInterface
   */
  function forward(address target, bytes memory data) external virtual override onlyL1Owner {
    Address.functionCall(target, data, "Forwarder call reverted");
  }

  /**
   * @notice The call MUST come from the L1 owner (via cross-chain message.) Reverts otherwise.
   */
  modifier onlyL1Owner() override {
    require(msg.sender == crossDomainMessenger(), "Sender is not the L2 messenger");
    _;
  }

  /**
   * @notice The call MUST come from the proposed L1 owner (via cross-chain message.) Reverts otherwise.
   */
  modifier onlyProposedL1Owner() override {
    require(msg.sender == AddressAliasHelper.applyL1ToL2Alias(s_l1PendingOwner), "Must be proposed L1 owner");
    _;
  }
}

import {IInbox} from "../dev/vendor/arb-bridge-eth/v0.8.0-custom/contracts/bridge/interfaces/IInbox.sol";
import {IBridge} from "../dev/vendor/arb-bridge-eth/v0.8.0-custom/contracts/bridge/interfaces/IBridge.sol";

contract MockArbitrumInbox is IInbox {
  event RetryableTicketNoRefundAliasRewriteCreated(
    address destAddr,
    uint256 arbTxCallValue,
    uint256 maxSubmissionCost,
    address submissionRefundAddress,
    address valueRefundAddress,
    uint256 maxGas,
    uint256 gasPriceBid,
    bytes data
  );

  function sendL2Message(bytes calldata messageData) external override returns (uint256) {
    return 0;
  }

  function sendUnsignedTransaction(
    uint256 maxGas,
    uint256 gasPriceBid,
    uint256 nonce,
    address destAddr,
    uint256 amount,
    bytes calldata data
  ) external override returns (uint256) {
    return 0;
  }

  function sendContractTransaction(
    uint256 maxGas,
    uint256 gasPriceBid,
    address destAddr,
    uint256 amount,
    bytes calldata data
  ) external override returns (uint256) {
    return 0;
  }

  function sendL1FundedUnsignedTransaction(
    uint256 maxGas,
    uint256 gasPriceBid,
    uint256 nonce,
    address destAddr,
    bytes calldata data
  ) external payable override returns (uint256) {
    return 0;
  }

  function sendL1FundedContractTransaction(
    uint256 maxGas,
    uint256 gasPriceBid,
    address destAddr,
    bytes calldata data
  ) external payable override returns (uint256) {
    return 0;
  }

  function createRetryableTicketNoRefundAliasRewrite(
    address destAddr,
    uint256 arbTxCallValue,
    uint256 maxSubmissionCost,
    address submissionRefundAddress,
    address valueRefundAddress,
    uint256 maxGas,
    uint256 gasPriceBid,
    bytes calldata data
  ) external payable override returns (uint256) {
    emit RetryableTicketNoRefundAliasRewriteCreated(
      destAddr,
      arbTxCallValue,
      maxSubmissionCost,
      submissionRefundAddress,
      valueRefundAddress,
      maxGas,
      gasPriceBid,
      data
    );
    return 42;
  }

  function createRetryableTicket(
    address destAddr,
    uint256 arbTxCallValue,
    uint256 maxSubmissionCost,
    address submissionRefundAddress,
    address valueRefundAddress,
    uint256 maxGas,
    uint256 gasPriceBid,
    bytes calldata data
  ) external payable override returns (uint256) {
    return 0;
  }

  function depositEth(address destAddr) external payable override returns (uint256) {
    return 0;
  }

  function depositEthRetryable(
    address destAddr,
    uint256 maxSubmissionCost,
    uint256 maxGas,
    uint256 maxGasPrice
  ) external payable override returns (uint256) {
    return 0;
  }

  function bridge() external view override returns (IBridge) {
    return IBridge(address(0));
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/AggregatorValidatorInterface.sol";

contract MockAggregatorValidator is AggregatorValidatorInterface {
  uint8 immutable id;

  constructor(uint8 id_) {
    id = id_;
  }

  event ValidateCalled(
    uint8 id,
    uint256 previousRoundId,
    int256 previousAnswer,
    uint256 currentRoundId,
    int256 currentAnswer
  );

  function validate(
    uint256 previousRoundId,
    int256 previousAnswer,
    uint256 currentRoundId,
    int256 currentAnswer
  ) external override returns (bool) {
    emit ValidateCalled(id, previousRoundId, previousAnswer, currentRoundId, currentAnswer);
    return true;
  }
}

pragma solidity ^0.8.0;

import "../ConfirmedOwner.sol";

contract Greeter is ConfirmedOwner {
  string public greeting;

  constructor(address owner) ConfirmedOwner(owner) {}

  function setGreeting(string calldata _greeting) external onlyOwner {
    require(bytes(_greeting).length > 0, "Invalid greeting length");
    greeting = _greeting;
  }

  function triggerRevert() external pure {
    require(false, "Greeter: revert triggered");
  }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

import "../ConfirmedOwner.sol";
import "../interfaces/KeeperCompatibleInterface.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title The EthBalanceMonitor contract
 * @notice A keeper-compatible contract that monitors and funds eth addresses
 */
contract EthBalanceMonitor is ConfirmedOwner, Pausable, KeeperCompatibleInterface {
  // observed limit of 45K + 10k buffer
  uint256 private constant MIN_GAS_FOR_TRANSFER = 55_000;

  event FundsAdded(uint256 amountAdded, uint256 newBalance, address sender);
  event FundsWithdrawn(uint256 amountWithdrawn, address payee);
  event TopUpSucceeded(address indexed recipient);
  event TopUpFailed(address indexed recipient);
  event KeeperRegistryAddressUpdated(address oldAddress, address newAddress);
  event MinWaitPeriodUpdated(uint256 oldMinWaitPeriod, uint256 newMinWaitPeriod);

  error InvalidWatchList();
  error OnlyKeeperRegistry();
  error DuplicateAddress(address duplicate);

  struct Target {
    bool isActive;
    uint96 minBalanceWei;
    uint96 topUpAmountWei;
    uint56 lastTopUpTimestamp; // enough space for 2 trillion years
  }

  address private s_keeperRegistryAddress;
  uint256 private s_minWaitPeriodSeconds;
  address[] private s_watchList;
  mapping(address => Target) internal s_targets;

  /**
   * @param keeperRegistryAddress The address of the keeper registry contract
   * @param minWaitPeriodSeconds The minimum wait period for addresses between funding
   */
  constructor(address keeperRegistryAddress, uint256 minWaitPeriodSeconds) ConfirmedOwner(msg.sender) {
    setKeeperRegistryAddress(keeperRegistryAddress);
    setMinWaitPeriodSeconds(minWaitPeriodSeconds);
  }

  /**
   * @notice Sets the list of addresses to watch and their funding parameters
   * @param addresses the list of addresses to watch
   * @param minBalancesWei the minimum balances for each address
   * @param topUpAmountsWei the amount to top up each address
   */
  function setWatchList(
    address[] calldata addresses,
    uint96[] calldata minBalancesWei,
    uint96[] calldata topUpAmountsWei
  ) external onlyOwner {
    if (addresses.length != minBalancesWei.length || addresses.length != topUpAmountsWei.length) {
      revert InvalidWatchList();
    }
    address[] memory oldWatchList = s_watchList;
    for (uint256 idx = 0; idx < oldWatchList.length; idx++) {
      s_targets[oldWatchList[idx]].isActive = false;
    }
    for (uint256 idx = 0; idx < addresses.length; idx++) {
      if (s_targets[addresses[idx]].isActive) {
        revert DuplicateAddress(addresses[idx]);
      }
      if (addresses[idx] == address(0)) {
        revert InvalidWatchList();
      }
      if (topUpAmountsWei[idx] == 0) {
        revert InvalidWatchList();
      }
      s_targets[addresses[idx]] = Target({
        isActive: true,
        minBalanceWei: minBalancesWei[idx],
        topUpAmountWei: topUpAmountsWei[idx],
        lastTopUpTimestamp: 0
      });
    }
    s_watchList = addresses;
  }

  /**
   * @notice Gets a list of addresses that are under funded
   * @return list of addresses that are underfunded
   */
  function getUnderfundedAddresses() public view returns (address[] memory) {
    address[] memory watchList = s_watchList;
    address[] memory needsFunding = new address[](watchList.length);
    uint256 count = 0;
    uint256 minWaitPeriod = s_minWaitPeriodSeconds;
    uint256 balance = address(this).balance;
    Target memory target;
    for (uint256 idx = 0; idx < watchList.length; idx++) {
      target = s_targets[watchList[idx]];
      if (
        target.lastTopUpTimestamp + minWaitPeriod <= block.timestamp &&
        balance >= target.topUpAmountWei &&
        watchList[idx].balance < target.minBalanceWei
      ) {
        needsFunding[count] = watchList[idx];
        count++;
        balance -= target.topUpAmountWei;
      }
    }
    if (count != watchList.length) {
      assembly {
        mstore(needsFunding, count)
      }
    }
    return needsFunding;
  }

  /**
   * @notice Send funds to the addresses provided
   * @param needsFunding the list of addresses to fund (addresses must be pre-approved)
   */
  function topUp(address[] memory needsFunding) public whenNotPaused {
    uint256 minWaitPeriodSeconds = s_minWaitPeriodSeconds;
    Target memory target;
    for (uint256 idx = 0; idx < needsFunding.length; idx++) {
      target = s_targets[needsFunding[idx]];
      if (
        target.isActive &&
        target.lastTopUpTimestamp + minWaitPeriodSeconds <= block.timestamp &&
        needsFunding[idx].balance < target.minBalanceWei
      ) {
        bool success = payable(needsFunding[idx]).send(target.topUpAmountWei);
        if (success) {
          s_targets[needsFunding[idx]].lastTopUpTimestamp = uint56(block.timestamp);
          emit TopUpSucceeded(needsFunding[idx]);
        } else {
          emit TopUpFailed(needsFunding[idx]);
        }
      }
      if (gasleft() < MIN_GAS_FOR_TRANSFER) {
        return;
      }
    }
  }

  /**
   * @notice Get list of addresses that are underfunded and return keeper-compatible payload
   * @return upkeepNeeded signals if upkeep is needed, performData is an abi encoded list of addresses that need funds
   */
  function checkUpkeep(bytes calldata)
    external
    view
    override
    whenNotPaused
    returns (bool upkeepNeeded, bytes memory performData)
  {
    address[] memory needsFunding = getUnderfundedAddresses();
    upkeepNeeded = needsFunding.length > 0;
    performData = abi.encode(needsFunding);
    return (upkeepNeeded, performData);
  }

  /**
   * @notice Called by keeper to send funds to underfunded addresses
   * @param performData The abi encoded list of addresses to fund
   */
  function performUpkeep(bytes calldata performData) external override onlyKeeperRegistry whenNotPaused {
    address[] memory needsFunding = abi.decode(performData, (address[]));
    topUp(needsFunding);
  }

  /**
   * @notice Withdraws the contract balance
   * @param amount The amount of eth (in wei) to withdraw
   * @param payee The address to pay
   */
  function withdraw(uint256 amount, address payable payee) external onlyOwner {
    require(payee != address(0));
    emit FundsWithdrawn(amount, payee);
    payee.transfer(amount);
  }

  /**
   * @notice Receive funds
   */
  receive() external payable {
    emit FundsAdded(msg.value, address(this).balance, msg.sender);
  }

  /**
   * @notice Sets the keeper registry address
   */
  function setKeeperRegistryAddress(address keeperRegistryAddress) public onlyOwner {
    require(keeperRegistryAddress != address(0));
    emit KeeperRegistryAddressUpdated(s_keeperRegistryAddress, keeperRegistryAddress);
    s_keeperRegistryAddress = keeperRegistryAddress;
  }

  /**
   * @notice Sets the minimum wait period (in seconds) for addresses between funding
   */
  function setMinWaitPeriodSeconds(uint256 period) public onlyOwner {
    emit MinWaitPeriodUpdated(s_minWaitPeriodSeconds, period);
    s_minWaitPeriodSeconds = period;
  }

  /**
   * @notice Gets the keeper registry address
   */
  function getKeeperRegistryAddress() external view returns (address keeperRegistryAddress) {
    return s_keeperRegistryAddress;
  }

  /**
   * @notice Gets the minimum wait period
   */
  function getMinWaitPeriodSeconds() external view returns (uint256) {
    return s_minWaitPeriodSeconds;
  }

  /**
   * @notice Gets the list of addresses being watched
   */
  function getWatchList() external view returns (address[] memory) {
    return s_watchList;
  }

  /**
   * @notice Gets configuration information for an address on the watchlist
   */
  function getAccountInfo(address targetAddress)
    external
    view
    returns (
      bool isActive,
      uint96 minBalanceWei,
      uint96 topUpAmountWei,
      uint56 lastTopUpTimestamp
    )
  {
    Target memory target = s_targets[targetAddress];
    return (target.isActive, target.minBalanceWei, target.topUpAmountWei, target.lastTopUpTimestamp);
  }

  /**
   * @notice Pauses the contract, which prevents executing performUpkeep
   */
  function pause() external onlyOwner {
    _pause();
  }

  /**
   * @notice Unpauses the contract
   */
  function unpause() external onlyOwner {
    _unpause();
  }

  modifier onlyKeeperRegistry() {
    if (msg.sender != s_keeperRegistryAddress) {
      revert OnlyKeeperRegistry();
    }
    _;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface KeeperCompatibleInterface {
  /**
   * @notice method that is simulated by the keepers to see if any work actually
   * needs to be performed. This method does does not actually need to be
   * executable, and since it is only ever simulated it can consume lots of gas.
   * @dev To ensure that it is never called, you may want to add the
   * cannotExecute modifier from KeeperBase to your implementation of this
   * method.
   * @param checkData specified in the upkeep registration so it is always the
   * same for a registered upkeep. This can easily be broken down into specific
   * arguments using `abi.decode`, so multiple upkeeps can be registered on the
   * same contract and easily differentiated by the contract.
   * @return upkeepNeeded boolean to indicate whether the keeper should call
   * performUpkeep or not.
   * @return performData bytes that the keeper should call performUpkeep with, if
   * upkeep is needed. If you would like to encode data to decode later, try
   * `abi.encode`.
   */
  function checkUpkeep(bytes calldata checkData) external returns (bool upkeepNeeded, bytes memory performData);

  /**
   * @notice method that is actually executed by the keepers, via the registry.
   * The data returned by the checkUpkeep simulation will be passed into
   * this method to actually be executed.
   * @dev The input to this method should not be trusted, and the caller of the
   * method should not even be restricted to any single registry. Anyone should
   * be able call it, and the input should be validated, there is no guarantee
   * that the data passed in is the performData returned from checkUpkeep. This
   * could happen due to malicious keepers, racing keepers, or simply a state
   * change while the performUpkeep transaction is waiting for confirmation.
   * Always validate the data passed in.
   * @param performData is the data which was passed back from the checkData
   * simulation. If it is encoded, it can easily be decoded into other types by
   * calling `abi.decode`. This data should not be trusted, and should be
   * validated against the contract's current state.
   */
  function performUpkeep(bytes calldata performData) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// SPDX-License-Identifier: MIT

/**
  The Cron contract is a chainlink keepers-powered cron job runner for smart contracts.
  The contract enables developers to trigger actions on various targets using cron
  strings to specify the cadence. For example, a user may have 3 tasks that require
  regular service in their dapp ecosystem:
    1) 0xAB..CD, update(1), "0 0 * * *"     --> runs update(1) on 0xAB..CD daily at midnight
    2) 0xAB..CD, update(2), "30 12 * * 0-4" --> runs update(2) on 0xAB..CD weekdays at 12:30
    3) 0x12..34, trigger(), "0 * * * *"     --> runs trigger() on 0x12..34 hourly

  To use this contract, a user first deploys this contract and registers it on the chainlink
  keeper registry. Then the user adds cron jobs by following these steps:
    1) Convert a cron string to an encoded cron spec by calling encodeCronString()
    2) Take the encoding, target, and handler, and create a job by sending a tx to createCronJob()
    3) Cron job is running :)
*/

pragma solidity 0.8.6;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/proxy/Proxy.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../ConfirmedOwner.sol";
import "../KeeperBase.sol";
import "../interfaces/KeeperCompatibleInterface.sol";
import {Cron as CronInternal, Spec} from "../libraries/internal/Cron.sol";
import {Cron as CronExternal} from "../libraries/external/Cron.sol";
import {getRevertMsg} from "../utils/utils.sol";

/**
 * @title The CronUpkeep contract
 * @notice A keeper-compatible contract that runs various tasks on cron schedules.
 * Users must use the encodeCronString() function to encode their cron jobs before
 * setting them. This keeps all the string manipulation off chain and reduces gas costs.
 */
contract CronUpkeep is KeeperCompatibleInterface, KeeperBase, ConfirmedOwner, Pausable, Proxy {
  using EnumerableSet for EnumerableSet.UintSet;

  event CronJobExecuted(uint256 indexed id, uint256 timestamp);
  event CronJobCreated(uint256 indexed id, address target, bytes handler);
  event CronJobDeleted(uint256 indexed id);

  error CallFailed(uint256 id, string reason);
  error CronJobIDNotFound(uint256 id);
  error InvalidHandler();
  error TickInFuture();
  error TickTooOld();
  error TickDoesntMatchSpec();

  address immutable s_delegate;
  uint256 private s_nextCronJobID = 1;
  EnumerableSet.UintSet private s_activeCronJobIDs;

  mapping(uint256 => uint256) private s_lastRuns;
  mapping(uint256 => Spec) private s_specs;
  mapping(uint256 => address) private s_targets;
  mapping(uint256 => bytes) private s_handlers;
  mapping(uint256 => bytes32) private s_handlerSignatures;

  /**
   * @param owner the initial owner of the contract
   * @param delegate the contract to delegate checkUpkeep calls to
   */
  constructor(address owner, address delegate) ConfirmedOwner(owner) {
    s_delegate = delegate;
  }

  /**
   * @notice Executes the cron job with id encoded in performData
   * @param performData abi encoding of cron job ID and the cron job's next run-at datetime
   */
  function performUpkeep(bytes calldata performData) external override whenNotPaused {
    (uint256 id, uint256 tickTime, address target, bytes memory handler) = abi.decode(
      performData,
      (uint256, uint256, address, bytes)
    );
    validate(id, tickTime, target, handler);
    s_lastRuns[id] = block.timestamp;
    (bool success, bytes memory payload) = target.call(handler);
    if (!success) {
      revert CallFailed(id, getRevertMsg(payload));
    }
    emit CronJobExecuted(id, block.timestamp);
  }

  /**
   * @notice Creates a cron job from the given encoded spec
   * @param target the destination contract of a cron job
   * @param handler the function signature on the target contract to call
   * @param encodedCronSpec abi encoding of a cron spec
   */
  function createCronJobFromEncodedSpec(
    address target,
    bytes memory handler,
    bytes memory encodedCronSpec
  ) external {
    Spec memory spec = abi.decode(encodedCronSpec, (Spec));
    createCronJobFromSpec(target, handler, spec);
  }

  /**
   * @notice Deletes the cron job matching the provided id. Reverts if
   * the id is not found.
   * @param id the id of the cron job to delete
   */
  function deleteCronJob(uint256 id) external onlyOwner onlyValidCronID(id) {
    delete s_lastRuns[id];
    delete s_specs[id];
    delete s_targets[id];
    delete s_handlers[id];
    delete s_handlerSignatures[id];
    s_activeCronJobIDs.remove(id);
    emit CronJobDeleted(id);
  }

  /**
   * @notice Pauses the contract, which prevents executing performUpkeep
   */
  function pause() external onlyOwner {
    _pause();
  }

  /**
   * @notice Unpauses the contract
   */
  function unpause() external onlyOwner {
    _unpause();
  }

  /**
   * @notice Get the id of an eligible cron job
   * @return upkeepNeeded signals if upkeep is needed, performData is an abi encoding
   * of the id and "next tick" of the elligible cron job
   */
  function checkUpkeep(bytes calldata) external override whenNotPaused cannotExecute returns (bool, bytes memory) {
    _delegate(s_delegate);
  }

  /**
   * @notice gets a list of active cron job IDs
   * @return list of active cron job IDs
   */
  function getActiveCronJobIDs() external view returns (uint256[] memory) {
    uint256 length = s_activeCronJobIDs.length();
    uint256[] memory jobIDs = new uint256[](length);
    for (uint256 idx = 0; idx < length; idx++) {
      jobIDs[idx] = s_activeCronJobIDs.at(idx);
    }
    return jobIDs;
  }

  /**
   * @notice gets a cron job
   * @param id the cron job ID
   * @return target - the address a cron job forwards the eth tx to
             handler - the encoded function sig to execute when forwarding a tx
             cronString - the string representing the cron job
             nextTick - the timestamp of the next time the cron job will run
   */
  function getCronJob(uint256 id)
    external
    view
    onlyValidCronID(id)
    returns (
      address target,
      bytes memory handler,
      string memory cronString,
      uint256 nextTick
    )
  {
    Spec memory spec = s_specs[id];
    return (s_targets[id], s_handlers[id], CronExternal.toCronString(spec), CronExternal.nextTick(spec));
  }

  /**
   * @notice Converts a cron string to a Spec, validates the spec, and encodes the spec.
   * This should only be called off-chain, as it is gas expensive!
   * @param cronString the cron string to convert and encode
   * @return the abi encoding of the Spec struct representing the cron string
   */
  function cronStringToEncodedSpec(string memory cronString) external pure returns (bytes memory) {
    return CronExternal.toEncodedSpec(cronString);
  }

  /**
   * @notice Adds a cron spec to storage and the ID to the list of jobs
   * @param target the destination contract of a cron job
   * @param handler the function signature on the target contract to call
   * @param spec the cron spec to create
   */
  function createCronJobFromSpec(
    address target,
    bytes memory handler,
    Spec memory spec
  ) internal onlyOwner {
    uint256 newID = s_nextCronJobID;
    s_activeCronJobIDs.add(newID);
    s_targets[newID] = target;
    s_handlers[newID] = handler;
    s_specs[newID] = spec;
    s_lastRuns[newID] = block.timestamp;
    s_handlerSignatures[newID] = handlerSig(target, handler);
    s_nextCronJobID++;
    emit CronJobCreated(newID, target, handler);
  }

  function _implementation() internal view override returns (address) {
    return s_delegate;
  }

  /**
   * @notice validates the input to performUpkeep
   * @param id the id of the cron job
   * @param tickTime the observed tick time
   * @param target the contract to forward the tx to
   * @param handler the handler of the contract receiving the forwarded tx
   */
  function validate(
    uint256 id,
    uint256 tickTime,
    address target,
    bytes memory handler
  ) private {
    if (block.timestamp < tickTime) {
      revert TickInFuture();
    }
    if (tickTime <= s_lastRuns[id]) {
      revert TickTooOld();
    }
    if (!CronInternal.matches(s_specs[id], tickTime)) {
      revert TickDoesntMatchSpec();
    }
    if (handlerSig(target, handler) != s_handlerSignatures[id]) {
      revert InvalidHandler();
    }
  }

  /**
   * @notice returns a unique identifier for target/handler pairs
   * @param target the contract to forward the tx to
   * @param handler the handler of the contract receiving the forwarded tx
   * @return a hash of the inputs
   */
  function handlerSig(address target, bytes memory handler) private pure returns (bytes32) {
    return keccak256(abi.encodePacked(target, handler));
  }

  modifier onlyValidCronID(uint256 id) {
    if (!s_activeCronJobIDs.contains(id)) {
      revert CronJobIDNotFound(id);
    }
    _;
  }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev This abstract contract provides a fallback function that delegates all calls to another contract using the EVM
 * instruction `delegatecall`. We refer to the second contract as the _implementation_ behind the proxy, and it has to
 * be specified by overriding the virtual {_implementation} function.
 *
 * Additionally, delegation to the implementation can be triggered manually through the {_fallback} function, or to a
 * different contract through the {_delegate} function.
 *
 * The success and return data of the delegated call will be returned back to the caller of the proxy.
 */
abstract contract Proxy {
    /**
     * @dev Delegates the current call to `implementation`.
     *
     * This function does not return to its internall call site, it will return directly to the external caller.
     */
    function _delegate(address implementation) internal virtual {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /**
     * @dev This is a virtual function that should be overriden so it returns the address to which the fallback function
     * and {_fallback} should delegate.
     */
    function _implementation() internal view virtual returns (address);

    /**
     * @dev Delegates the current call to the address returned by `_implementation()`.
     *
     * This function does not return to its internall call site, it will return directly to the external caller.
     */
    function _fallback() internal virtual {
        _beforeFallback();
        _delegate(_implementation());
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if no other
     * function in the contract matches the call data.
     */
    fallback() external payable virtual {
        _fallback();
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if call data
     * is empty.
     */
    receive() external payable virtual {
        _fallback();
    }

    /**
     * @dev Hook that is called before falling back to the implementation. Can happen as part of a manual `_fallback`
     * call, or as part of the Solidity `fallback` or `receive` functions.
     *
     * If overriden should call `super._beforeFallback()`.
     */
    function _beforeFallback() internal virtual {}
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
 */
library EnumerableSet {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;
        // Position of the value in the `values` array, plus 1 because index 0
        // means a value is not in the set.
        mapping(bytes32 => uint256) _indexes;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We read and store the value's index to prevent multiple reads from the same storage slot
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) {
            // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            if (lastIndex != toDeleteIndex) {
                bytes32 lastvalue = set._values[lastIndex];

                // Move the last value to the index where the value to delete is
                set._values[toDeleteIndex] = lastvalue;
                // Update the index for the moved value
                set._indexes[lastvalue] = valueIndex; // Replace lastvalue's index to valueIndex
            }

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the index for the deleted slot
            delete set._indexes[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        return set._values[index];
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function _values(Set storage set) private view returns (bytes32[] memory) {
        return set._values;
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(Bytes32Set storage set) internal view returns (bytes32[] memory) {
        return _values(set._inner);
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(AddressSet storage set) internal view returns (address[] memory) {
        bytes32[] memory store = _values(set._inner);
        address[] memory result;

        assembly {
            result := store
        }

        return result;
    }

    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(UintSet storage set) internal view returns (uint256[] memory) {
        bytes32[] memory store = _values(set._inner);
        uint256[] memory result;

        assembly {
            result := store
        }

        return result;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract KeeperBase {
  error OnlySimulatedBackend();

  /**
   * @notice method that allows it to be simulated via eth_call by checking that
   * the sender is the zero address.
   */
  function preventExecution() internal view {
    if (tx.origin != address(0)) {
      revert OnlySimulatedBackend();
    }
  }

  /**
   * @notice modifier that allows it to be simulated via eth_call by checking
   * that the sender is the zero address.
   */
  modifier cannotExecute() {
    preventExecution();
    _;
  }
}

// SPDX-License-Identifier: MIT

/*
  The Cron contract serves two primary functions:
    * parsing cron-formatted strings like "0 0 * * *" into
      structs called "Specs"
    * computing the "next tick" of a cron spec

  Because manipulating strings is gas-expensive in solidity,
  the intended use of this contract is for users to first convert
  their cron strings to encoded Spec structs via toEncodedSpec().
  Then, the user stores the Spec on chain. Finally, users use the nextTick(),
  function to determine the datetime of the next cron job run.

  Cron jobs are interpreted according to this format:

  ┌───────────── minute (0 - 59)
  │ ┌───────────── hour (0 - 23)
  │ │ ┌───────────── day of the month (1 - 31)
  │ │ │ ┌───────────── month (1 - 12)
  │ │ │ │ ┌───────────── day of the week (0 - 6) (Monday to Sunday)
  │ │ │ │ │
  │ │ │ │ │
  │ │ │ │ │
  * * * * *

  Special limitations:
    * there is no year field
    * no special characters: ? L W #
    * lists can have a max length of 26
    * no words like JAN / FEB or MON / TUES
*/

pragma solidity 0.8.6;

import "../../vendor/Strings.sol";
import "../../vendor/DateTime.sol";

// The fields of a cron spec, by name
string constant MINUTE = "minute";
string constant HOUR = "hour";
string constant DAY = "day";
string constant MONTH = "month";
string constant DAY_OF_WEEK = "day of week";

error UnknownFieldType();
error InvalidSpec(string reason);
error InvalidField(string field, string reason);
error ListTooLarge();

// Set of enums representing a cron field type
enum FieldType {
  WILD,
  EXACT,
  INTERVAL,
  RANGE,
  LIST
}

// A spec represents a cron job by decomposing it into 5 fields
struct Spec {
  Field minute;
  Field hour;
  Field day;
  Field month;
  Field dayOfWeek;
}

// A field represents a single element in a cron spec. There are 5 types
// of fields (see above). Not all properties of this struct are present at once.
struct Field {
  FieldType fieldType;
  uint8 singleValue;
  uint8 interval;
  uint8 rangeStart;
  uint8 rangeEnd;
  uint8 listLength;
  uint8[26] list;
}

/**
 * @title The Cron library
 * @notice A utility contract for encoding/decoding cron strings (ex: 0 0 * * *) into an
 * abstraction called a Spec. The library also includes a spec function, nextTick(), which
 * determines the next time a cron job should fire based on the current block timestamp.
 */
library Cron {
  using strings for *;

  /**
   * @notice nextTick calculates the next datetime that a spec "ticks", starting
   * from the current block timestamp. This is gas-intensive and therefore should
   * only be called off-chain.
   * @param spec the spec to evaluate
   * @return the next tick
   * @dev this is the internal version of the library. There is also an external version.
   */
  function nextTick(Spec memory spec) internal view returns (uint256) {
    uint16 year = DateTime.getYear(block.timestamp);
    uint8 month = DateTime.getMonth(block.timestamp);
    uint8 day = DateTime.getDay(block.timestamp);
    uint8 hour = DateTime.getHour(block.timestamp);
    uint8 minute = DateTime.getMinute(block.timestamp);
    uint8 dayOfWeek;
    for (; true; year++) {
      for (; month <= 12; month++) {
        if (!matches(spec.month, month)) {
          day = 1;
          hour = 0;
          minute = 0;
          continue;
        }
        uint8 maxDay = DateTime.getDaysInMonth(month, year);
        for (; day <= maxDay; day++) {
          if (!matches(spec.day, day)) {
            hour = 0;
            minute = 0;
            continue;
          }
          dayOfWeek = DateTime.getWeekday(DateTime.toTimestamp(year, month, day));
          if (!matches(spec.dayOfWeek, dayOfWeek)) {
            hour = 0;
            minute = 0;
            continue;
          }
          for (; hour < 24; hour++) {
            if (!matches(spec.hour, hour)) {
              minute = 0;
              continue;
            }
            for (; minute < 60; minute++) {
              if (!matches(spec.minute, minute)) {
                continue;
              }
              return DateTime.toTimestamp(year, month, day, hour, minute);
            }
            minute = 0;
          }
          hour = 0;
        }
        day = 1;
      }
      month = 1;
    }
  }

  /**
   * @notice lastTick calculates the previous datetime that a spec "ticks", starting
   * from the current block timestamp. This is gas-intensive and therefore should
   * only be called off-chain.
   * @param spec the spec to evaluate
   * @return the next tick
   */
  function lastTick(Spec memory spec) internal view returns (uint256) {
    uint16 year = DateTime.getYear(block.timestamp);
    uint8 month = DateTime.getMonth(block.timestamp);
    uint8 day = DateTime.getDay(block.timestamp);
    uint8 hour = DateTime.getHour(block.timestamp);
    uint8 minute = DateTime.getMinute(block.timestamp);
    uint8 dayOfWeek;
    bool resetDay;
    for (; true; year--) {
      for (; month > 0; month--) {
        if (!matches(spec.month, month)) {
          resetDay = true;
          hour = 23;
          minute = 59;
          continue;
        }
        if (resetDay) {
          day = DateTime.getDaysInMonth(month, year);
        }
        for (; day > 0; day--) {
          if (!matches(spec.day, day)) {
            hour = 23;
            minute = 59;
            continue;
          }
          dayOfWeek = DateTime.getWeekday(DateTime.toTimestamp(year, month, day));
          if (!matches(spec.dayOfWeek, dayOfWeek)) {
            hour = 23;
            minute = 59;
            continue;
          }
          for (; hour >= 0; hour--) {
            if (!matches(spec.hour, hour)) {
              minute = 59;
              if (hour == 0) {
                break;
              }
              continue;
            }
            for (; minute >= 0; minute--) {
              if (!matches(spec.minute, minute)) {
                if (minute == 0) {
                  break;
                }
                continue;
              }
              return DateTime.toTimestamp(year, month, day, hour, minute);
            }
            minute = 59;
            if (hour == 0) {
              break;
            }
          }
          hour = 23;
        }
        resetDay = true;
      }
      month = 12;
    }
  }

  /**
   * @notice matches evaluates whether or not a spec "ticks" at a given timestamp
   * @param spec the spec to evaluate
   * @param timestamp the timestamp to compare against
   * @return true / false if they match
   */
  function matches(Spec memory spec, uint256 timestamp) internal view returns (bool) {
    DateTime._DateTime memory dt = DateTime.parseTimestamp(timestamp);
    return
      matches(spec.month, dt.month) &&
      matches(spec.day, dt.day) &&
      matches(spec.hour, dt.hour) &&
      matches(spec.minute, dt.minute);
  }

  /**
   * @notice toSpec converts a cron string to a spec struct. This is gas-intensive
   * and therefore should only be called off-chain.
   * @param cronString the cron string
   * @return the spec struct
   */
  function toSpec(string memory cronString) internal pure returns (Spec memory) {
    strings.slice memory space = strings.toSlice(" ");
    strings.slice memory cronSlice = strings.toSlice(cronString);
    if (cronSlice.count(space) != 4) {
      revert InvalidSpec("4 spaces required");
    }
    strings.slice memory minuteSlice = cronSlice.split(space);
    strings.slice memory hourSlice = cronSlice.split(space);
    strings.slice memory daySlice = cronSlice.split(space);
    strings.slice memory monthSlice = cronSlice.split(space);
    // DEV: dayOfWeekSlice = cronSlice
    // The cronSlice now contains the last section of the cron job,
    // which corresponds to the day of week
    if (
      minuteSlice.len() == 0 ||
      hourSlice.len() == 0 ||
      daySlice.len() == 0 ||
      monthSlice.len() == 0 ||
      cronSlice.len() == 0
    ) {
      revert InvalidSpec("some fields missing");
    }
    return
      validate(
        Spec({
          minute: sliceToField(minuteSlice),
          hour: sliceToField(hourSlice),
          day: sliceToField(daySlice),
          month: sliceToField(monthSlice),
          dayOfWeek: sliceToField(cronSlice)
        })
      );
  }

  /**
   * @notice toEncodedSpec converts a cron string to an abi-encoded spec. This is gas-intensive
   * and therefore should only be called off-chain.
   * @param cronString the cron string
   * @return the abi-encoded spec
   */
  function toEncodedSpec(string memory cronString) internal pure returns (bytes memory) {
    return abi.encode(toSpec(cronString));
  }

  /**
   * @notice toCronString converts a cron spec to a human-readable cron string. This is gas-intensive
   * and therefore should only be called off-chain.
   * @param spec the cron spec
   * @return the corresponding cron string
   */
  function toCronString(Spec memory spec) internal pure returns (string memory) {
    return
      string(
        bytes.concat(
          fieldToBstring(spec.minute),
          " ",
          fieldToBstring(spec.hour),
          " ",
          fieldToBstring(spec.day),
          " ",
          fieldToBstring(spec.month),
          " ",
          fieldToBstring(spec.dayOfWeek)
        )
      );
  }

  /**
   * @notice matches evaluates if a values matches a field.
   * ex: 3 matches *, 3 matches 0-5, 3 does not match 0,2,4
   * @param field the field struct to match against
   * @param value the value of a field
   * @return true / false if they match
   */
  function matches(Field memory field, uint8 value) private pure returns (bool) {
    if (field.fieldType == FieldType.WILD) {
      return true;
    } else if (field.fieldType == FieldType.INTERVAL) {
      return value % field.interval == 0;
    } else if (field.fieldType == FieldType.EXACT) {
      return value == field.singleValue;
    } else if (field.fieldType == FieldType.RANGE) {
      return value >= field.rangeStart && value <= field.rangeEnd;
    } else if (field.fieldType == FieldType.LIST) {
      for (uint256 idx = 0; idx < field.listLength; idx++) {
        if (value == field.list[idx]) {
          return true;
        }
      }
      return false;
    }
    revert UnknownFieldType();
  }

  // VALIDATIONS

  /**
   * @notice validate validates a spec, reverting if any errors are found
   * @param spec the spec to validate
   * @return the original spec
   */
  function validate(Spec memory spec) private pure returns (Spec memory) {
    validateField(spec.dayOfWeek, DAY_OF_WEEK, 0, 6);
    validateField(spec.month, MONTH, 1, 12);
    uint8 maxDay = maxDayForMonthField(spec.month);
    validateField(spec.day, DAY, 1, maxDay);
    validateField(spec.hour, HOUR, 0, 23);
    validateField(spec.minute, MINUTE, 0, 59);
    return spec;
  }

  /**
   * @notice validateField validates the value of a field. It reverts if an error is found.
   * @param field the field to validate
   * @param fieldName the name of the field ex "minute" or "hour"
   * @param min the minimum value a field can have (usually 1 or 0)
   * @param max the maximum value a field can have (ex minute = 59, hour = 23)
   */
  function validateField(
    Field memory field,
    string memory fieldName,
    uint8 min,
    uint8 max
  ) private pure {
    if (field.fieldType == FieldType.WILD) {
      return;
    } else if (field.fieldType == FieldType.EXACT) {
      if (field.singleValue < min || field.singleValue > max) {
        string memory reason = string(
          bytes.concat("value must be >=,", uintToBString(min), " and <=", uintToBString(max))
        );
        revert InvalidField(fieldName, reason);
      }
    } else if (field.fieldType == FieldType.INTERVAL) {
      if (field.interval < 1 || field.interval > max) {
        string memory reason = string(
          bytes.concat("inverval must be */(", uintToBString(1), "-", uintToBString(max), ")")
        );
        revert InvalidField(fieldName, reason);
      }
    } else if (field.fieldType == FieldType.RANGE) {
      if (field.rangeEnd > max || field.rangeEnd <= field.rangeStart) {
        string memory reason = string(
          bytes.concat("inverval must be within ", uintToBString(min), "-", uintToBString(max))
        );
        revert InvalidField(fieldName, reason);
      }
    } else if (field.fieldType == FieldType.LIST) {
      if (field.listLength < 2) {
        revert InvalidField(fieldName, "lists must have at least 2 items");
      }
      string memory reason = string(
        bytes.concat("items in list must be within ", uintToBString(min), "-", uintToBString(max))
      );
      uint8 listItem;
      for (uint256 idx = 0; idx < field.listLength; idx++) {
        listItem = field.list[idx];
        if (listItem < min || listItem > max) {
          revert InvalidField(fieldName, reason);
        }
      }
    } else {
      revert UnknownFieldType();
    }
  }

  /**
   * @notice maxDayForMonthField returns the maximum valid day given the month field
   * @param month the month field
   * @return the max day
   */
  function maxDayForMonthField(Field memory month) private pure returns (uint8) {
    // DEV: ranges are always safe because any two consecutive months will always
    // contain a month with 31 days
    if (month.fieldType == FieldType.WILD || month.fieldType == FieldType.RANGE) {
      return 31;
    } else if (month.fieldType == FieldType.EXACT) {
      // DEV: assume leap year in order to get max value
      return DateTime.getDaysInMonth(month.singleValue, 4);
    } else if (month.fieldType == FieldType.INTERVAL) {
      if (month.interval == 9 || month.interval == 11) {
        return 30;
      } else {
        return 31;
      }
    } else if (month.fieldType == FieldType.LIST) {
      uint8 result;
      for (uint256 idx = 0; idx < month.listLength; idx++) {
        // DEV: assume leap year in order to get max value
        uint8 daysInMonth = DateTime.getDaysInMonth(month.list[idx], 4);
        if (daysInMonth == 31) {
          return daysInMonth;
        }
        if (daysInMonth > result) {
          result = daysInMonth;
        }
      }
      return result;
    } else {
      revert UnknownFieldType();
    }
  }

  /**
   * @notice sliceToField converts a strings.slice to a field struct
   * @param fieldSlice the slice of a string representing the field of a cron job
   * @return the field
   */
  function sliceToField(strings.slice memory fieldSlice) private pure returns (Field memory) {
    strings.slice memory star = strings.toSlice("*");
    strings.slice memory dash = strings.toSlice("-");
    strings.slice memory slash = strings.toSlice("/");
    strings.slice memory comma = strings.toSlice(",");
    Field memory field;
    if (fieldSlice.equals(star)) {
      field.fieldType = FieldType.WILD;
    } else if (fieldSlice.contains(dash)) {
      field.fieldType = FieldType.RANGE;
      strings.slice memory start = fieldSlice.split(dash);
      field.rangeStart = sliceToUint8(start);
      field.rangeEnd = sliceToUint8(fieldSlice);
    } else if (fieldSlice.contains(slash)) {
      field.fieldType = FieldType.INTERVAL;
      fieldSlice.split(slash);
      field.interval = sliceToUint8(fieldSlice);
    } else if (fieldSlice.contains(comma)) {
      field.fieldType = FieldType.LIST;
      strings.slice memory token;
      while (fieldSlice.len() > 0) {
        if (field.listLength > 25) {
          revert ListTooLarge();
        }
        token = fieldSlice.split(comma);
        field.list[field.listLength] = sliceToUint8(token);
        field.listLength++;
      }
    } else {
      // needs input validation
      field.fieldType = FieldType.EXACT;
      field.singleValue = sliceToUint8(fieldSlice);
    }
    return field;
  }

  /**
   * @notice fieldToBstring converts a field to the bytes representation of that field string
   * @param field the field to stringify
   * @return bytes representing the string, ex: bytes("*")
   */
  function fieldToBstring(Field memory field) private pure returns (bytes memory) {
    if (field.fieldType == FieldType.WILD) {
      return "*";
    } else if (field.fieldType == FieldType.EXACT) {
      return uintToBString(uint256(field.singleValue));
    } else if (field.fieldType == FieldType.RANGE) {
      return bytes.concat(uintToBString(field.rangeStart), "-", uintToBString(field.rangeEnd));
    } else if (field.fieldType == FieldType.INTERVAL) {
      return bytes.concat("*/", uintToBString(uint256(field.interval)));
    } else if (field.fieldType == FieldType.LIST) {
      bytes memory result = uintToBString(field.list[0]);
      for (uint256 idx = 1; idx < field.listLength; idx++) {
        result = bytes.concat(result, ",", uintToBString(field.list[idx]));
      }
      return result;
    }
    revert UnknownFieldType();
  }

  /**
   * @notice uintToBString converts a uint256 to a bytes representation of that uint as a string
   * @param n the number to stringify
   * @return bytes representing the string, ex: bytes("1")
   */
  function uintToBString(uint256 n) private pure returns (bytes memory) {
    if (n == 0) {
      return "0";
    }
    uint256 j = n;
    uint256 len;
    while (j != 0) {
      len++;
      j /= 10;
    }
    bytes memory bstr = new bytes(len);
    uint256 k = len;
    while (n != 0) {
      k = k - 1;
      uint8 temp = (48 + uint8(n - (n / 10) * 10));
      bytes1 b1 = bytes1(temp);
      bstr[k] = b1;
      n /= 10;
    }
    return bstr;
  }

  /**
   * @notice sliceToUint8 converts a strings.slice to uint8
   * @param slice the string slice to convert to a uint8
   * @return the number that the string represents ex: "20" --> 20
   */
  function sliceToUint8(strings.slice memory slice) private pure returns (uint8) {
    bytes memory b = bytes(slice.toString());
    uint8 i;
    uint8 result = 0;
    for (i = 0; i < b.length; i++) {
      uint8 c = uint8(b[i]);
      if (c >= 48 && c <= 57) {
        result = result * 10 + (c - 48);
      }
    }
    return result;
  }
}

pragma solidity 0.8.6;

import {Cron as CronInternal, Spec} from "../internal/Cron.sol";

/**
 * @title The Cron library
 * @notice A utility contract for encoding/decoding cron strings (ex: 0 0 * * *) into an
 * abstraction called a Spec. The library also includes a spec function, nextTick(), which
 * determines the next time a cron job should fire based on the current block timestamp.
 * @dev this is the external version of the library, which relies on the internal library
 * by the same name.
 */
library Cron {
  using CronInternal for Spec;
  using CronInternal for string;

  /**
   * @notice nextTick calculates the next datetime that a spec "ticks", starting
   * from the current block timestamp. This is gas-intensive and therefore should
   * only be called off-chain.
   * @param spec the spec to evaluate
   * @return the next tick
   */
  function nextTick(Spec calldata spec) public view returns (uint256) {
    return spec.nextTick();
  }

  /**
   * @notice lastTick calculates the previous datetime that a spec "ticks", starting
   * from the current block timestamp. This is gas-intensive and therefore should
   * only be called off-chain.
   * @param spec the spec to evaluate
   * @return the next tick
   */
  function lastTick(Spec calldata spec) public view returns (uint256) {
    return spec.lastTick();
  }

  /**
   * @notice matches evaluates whether or not a spec "ticks" at a given timestamp
   * @param spec the spec to evaluate
   * @param timestamp the timestamp to compare against
   * @return true / false if they match
   */
  function matches(Spec calldata spec, uint256 timestamp) public view returns (bool) {
    return spec.matches(timestamp);
  }

  /**
   * @notice toSpec converts a cron string to a spec struct. This is gas-intensive
   * and therefore should only be called off-chain.
   * @param cronString the cron string
   * @return the spec struct
   */
  function toSpec(string calldata cronString) public pure returns (Spec memory) {
    return cronString.toSpec();
  }

  /**
   * @notice toEncodedSpec converts a cron string to an abi-encoded spec. This is gas-intensive
   * and therefore should only be called off-chain.
   * @param cronString the cron string
   * @return the abi-encoded spec
   */
  function toEncodedSpec(string calldata cronString) public pure returns (bytes memory) {
    return cronString.toEncodedSpec();
  }

  /**
   * @notice toCronString converts a cron spec to a human-readable cron string. This is gas-intensive
   * and therefore should only be called off-chain.
   * @param spec the cron spec
   * @return the corresponding cron string
   */
  function toCronString(Spec calldata spec) public pure returns (string memory) {
    return spec.toCronString();
  }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

/**
 * @notice getRevertMsg extracts a revert reason from a failed contract call
 */
function getRevertMsg(bytes memory payload) pure returns (string memory) {
  if (payload.length < 68) return "transaction reverted silently";
  assembly {
    payload := add(payload, 0x04)
  }
  return abi.decode(payload, (string));
}

// SPDX-License-Identifier: Apache 2.0

/*
 * @title String & slice utility library for Solidity contracts.
 * @author Nick Johnson <[email protected]>
 *
 * @dev Functionality in this library is largely implemented using an
 *      abstraction called a 'slice'. A slice represents a part of a string -
 *      anything from the entire string to a single character, or even no
 *      characters at all (a 0-length slice). Since a slice only has to specify
 *      an offset and a length, copying and manipulating slices is a lot less
 *      expensive than copying and manipulating the strings they reference.
 *
 *      To further reduce gas costs, most functions on slice that need to return
 *      a slice modify the original one instead of allocating a new one; for
 *      instance, `s.split(".")` will return the text up to the first '.',
 *      modifying s to only contain the remainder of the string after the '.'.
 *      In situations where you do not want to modify the original slice, you
 *      can make a copy first with `.copy()`, for example:
 *      `s.copy().split(".")`. Try and avoid using this idiom in loops; since
 *      Solidity has no memory management, it will result in allocating many
 *      short-lived slices that are later discarded.
 *
 *      Functions that return two slices come in two versions: a non-allocating
 *      version that takes the second slice as an argument, modifying it in
 *      place, and an allocating version that allocates and returns the second
 *      slice; see `nextRune` for example.
 *
 *      Functions that have to copy string data will return strings rather than
 *      slices; these can be cast back to slices for further processing if
 *      required.
 *
 *      For convenience, some functions are provided with non-modifying
 *      variants that create a new slice and return both; for instance,
 *      `s.splitNew('.')` leaves s unmodified, and returns two values
 *      corresponding to the left and right parts of the string.
 */

pragma solidity ^0.8.0;

library strings {
  struct slice {
    uint256 _len;
    uint256 _ptr;
  }

  function memcpy(
    uint256 dest,
    uint256 src,
    uint256 len
  ) private pure {
    // Copy word-length chunks while possible
    for (; len >= 32; len -= 32) {
      assembly {
        mstore(dest, mload(src))
      }
      dest += 32;
      src += 32;
    }

    // Copy remaining bytes
    uint256 mask = type(uint256).max;
    if (len > 0) {
      mask = 256**(32 - len) - 1;
    }
    assembly {
      let srcpart := and(mload(src), not(mask))
      let destpart := and(mload(dest), mask)
      mstore(dest, or(destpart, srcpart))
    }
  }

  /*
   * @dev Returns a slice containing the entire string.
   * @param self The string to make a slice from.
   * @return A newly allocated slice containing the entire string.
   */
  function toSlice(string memory self) internal pure returns (slice memory) {
    uint256 ptr;
    assembly {
      ptr := add(self, 0x20)
    }
    return slice(bytes(self).length, ptr);
  }

  /*
   * @dev Returns the length of a null-terminated bytes32 string.
   * @param self The value to find the length of.
   * @return The length of the string, from 0 to 32.
   */
  function len(bytes32 self) internal pure returns (uint256) {
    uint256 ret;
    if (self == 0) return 0;
    if (uint256(self) & type(uint128).max == 0) {
      ret += 16;
      self = bytes32(uint256(self) / 0x100000000000000000000000000000000);
    }
    if (uint256(self) & type(uint64).max == 0) {
      ret += 8;
      self = bytes32(uint256(self) / 0x10000000000000000);
    }
    if (uint256(self) & type(uint32).max == 0) {
      ret += 4;
      self = bytes32(uint256(self) / 0x100000000);
    }
    if (uint256(self) & type(uint16).max == 0) {
      ret += 2;
      self = bytes32(uint256(self) / 0x10000);
    }
    if (uint256(self) & type(uint8).max == 0) {
      ret += 1;
    }
    return 32 - ret;
  }

  /*
   * @dev Returns a slice containing the entire bytes32, interpreted as a
   *      null-terminated utf-8 string.
   * @param self The bytes32 value to convert to a slice.
   * @return A new slice containing the value of the input argument up to the
   *         first null.
   */
  function toSliceB32(bytes32 self) internal pure returns (slice memory ret) {
    // Allocate space for `self` in memory, copy it there, and point ret at it
    assembly {
      let ptr := mload(0x40)
      mstore(0x40, add(ptr, 0x20))
      mstore(ptr, self)
      mstore(add(ret, 0x20), ptr)
    }
    ret._len = len(self);
  }

  /*
   * @dev Returns a new slice containing the same data as the current slice.
   * @param self The slice to copy.
   * @return A new slice containing the same data as `self`.
   */
  function copy(slice memory self) internal pure returns (slice memory) {
    return slice(self._len, self._ptr);
  }

  /*
   * @dev Copies a slice to a new string.
   * @param self The slice to copy.
   * @return A newly allocated string containing the slice's text.
   */
  function toString(slice memory self) internal pure returns (string memory) {
    string memory ret = new string(self._len);
    uint256 retptr;
    assembly {
      retptr := add(ret, 32)
    }

    memcpy(retptr, self._ptr, self._len);
    return ret;
  }

  /*
   * @dev Returns the length in runes of the slice. Note that this operation
   *      takes time proportional to the length of the slice; avoid using it
   *      in loops, and call `slice.empty()` if you only need to know whether
   *      the slice is empty or not.
   * @param self The slice to operate on.
   * @return The length of the slice in runes.
   */
  function len(slice memory self) internal pure returns (uint256 l) {
    // Starting at ptr-31 means the LSB will be the byte we care about
    uint256 ptr = self._ptr - 31;
    uint256 end = ptr + self._len;
    for (l = 0; ptr < end; l++) {
      uint8 b;
      assembly {
        b := and(mload(ptr), 0xFF)
      }
      if (b < 0x80) {
        ptr += 1;
      } else if (b < 0xE0) {
        ptr += 2;
      } else if (b < 0xF0) {
        ptr += 3;
      } else if (b < 0xF8) {
        ptr += 4;
      } else if (b < 0xFC) {
        ptr += 5;
      } else {
        ptr += 6;
      }
    }
  }

  /*
   * @dev Returns true if the slice is empty (has a length of 0).
   * @param self The slice to operate on.
   * @return True if the slice is empty, False otherwise.
   */
  function empty(slice memory self) internal pure returns (bool) {
    return self._len == 0;
  }

  /*
   * @dev Returns a positive number if `other` comes lexicographically after
   *      `self`, a negative number if it comes before, or zero if the
   *      contents of the two slices are equal. Comparison is done per-rune,
   *      on unicode codepoints.
   * @param self The first slice to compare.
   * @param other The second slice to compare.
   * @return The result of the comparison.
   */
  function compare(slice memory self, slice memory other)
    internal
    pure
    returns (int256)
  {
    uint256 shortest = self._len;
    if (other._len < self._len) shortest = other._len;

    uint256 selfptr = self._ptr;
    uint256 otherptr = other._ptr;
    for (uint256 idx = 0; idx < shortest; idx += 32) {
      uint256 a;
      uint256 b;
      assembly {
        a := mload(selfptr)
        b := mload(otherptr)
      }
      if (a != b) {
        // Mask out irrelevant bytes and check again
        uint256 mask = type(uint256).max; // 0xffff...
        if (shortest < 32) {
          mask = ~(2**(8 * (32 - shortest + idx)) - 1);
        }
        unchecked {
          uint256 diff = (a & mask) - (b & mask);
          if (diff != 0) return int256(diff);
        }
      }
      selfptr += 32;
      otherptr += 32;
    }
    return int256(self._len) - int256(other._len);
  }

  /*
   * @dev Returns true if the two slices contain the same text.
   * @param self The first slice to compare.
   * @param self The second slice to compare.
   * @return True if the slices are equal, false otherwise.
   */
  function equals(slice memory self, slice memory other)
    internal
    pure
    returns (bool)
  {
    return compare(self, other) == 0;
  }

  /*
   * @dev Extracts the first rune in the slice into `rune`, advancing the
   *      slice to point to the next rune and returning `self`.
   * @param self The slice to operate on.
   * @param rune The slice that will contain the first rune.
   * @return `rune`.
   */
  function nextRune(slice memory self, slice memory rune)
    internal
    pure
    returns (slice memory)
  {
    rune._ptr = self._ptr;

    if (self._len == 0) {
      rune._len = 0;
      return rune;
    }

    uint256 l;
    uint256 b;
    // Load the first byte of the rune into the LSBs of b
    assembly {
      b := and(mload(sub(mload(add(self, 32)), 31)), 0xFF)
    }
    if (b < 0x80) {
      l = 1;
    } else if (b < 0xE0) {
      l = 2;
    } else if (b < 0xF0) {
      l = 3;
    } else {
      l = 4;
    }

    // Check for truncated codepoints
    if (l > self._len) {
      rune._len = self._len;
      self._ptr += self._len;
      self._len = 0;
      return rune;
    }

    self._ptr += l;
    self._len -= l;
    rune._len = l;
    return rune;
  }

  /*
   * @dev Returns the first rune in the slice, advancing the slice to point
   *      to the next rune.
   * @param self The slice to operate on.
   * @return A slice containing only the first rune from `self`.
   */
  function nextRune(slice memory self)
    internal
    pure
    returns (slice memory ret)
  {
    nextRune(self, ret);
  }

  /*
   * @dev Returns the number of the first codepoint in the slice.
   * @param self The slice to operate on.
   * @return The number of the first codepoint in the slice.
   */
  function ord(slice memory self) internal pure returns (uint256 ret) {
    if (self._len == 0) {
      return 0;
    }

    uint256 word;
    uint256 length;
    uint256 divisor = 2**248;

    // Load the rune into the MSBs of b
    assembly {
      word := mload(mload(add(self, 32)))
    }
    uint256 b = word / divisor;
    if (b < 0x80) {
      ret = b;
      length = 1;
    } else if (b < 0xE0) {
      ret = b & 0x1F;
      length = 2;
    } else if (b < 0xF0) {
      ret = b & 0x0F;
      length = 3;
    } else {
      ret = b & 0x07;
      length = 4;
    }

    // Check for truncated codepoints
    if (length > self._len) {
      return 0;
    }

    for (uint256 i = 1; i < length; i++) {
      divisor = divisor / 256;
      b = (word / divisor) & 0xFF;
      if (b & 0xC0 != 0x80) {
        // Invalid UTF-8 sequence
        return 0;
      }
      ret = (ret * 64) | (b & 0x3F);
    }

    return ret;
  }

  /*
   * @dev Returns the keccak-256 hash of the slice.
   * @param self The slice to hash.
   * @return The hash of the slice.
   */
  function keccak(slice memory self) internal pure returns (bytes32 ret) {
    assembly {
      ret := keccak256(mload(add(self, 32)), mload(self))
    }
  }

  /*
   * @dev Returns true if `self` starts with `needle`.
   * @param self The slice to operate on.
   * @param needle The slice to search for.
   * @return True if the slice starts with the provided text, false otherwise.
   */
  function startsWith(slice memory self, slice memory needle)
    internal
    pure
    returns (bool)
  {
    if (self._len < needle._len) {
      return false;
    }

    if (self._ptr == needle._ptr) {
      return true;
    }

    bool equal;
    assembly {
      let length := mload(needle)
      let selfptr := mload(add(self, 0x20))
      let needleptr := mload(add(needle, 0x20))
      equal := eq(keccak256(selfptr, length), keccak256(needleptr, length))
    }
    return equal;
  }

  /*
   * @dev If `self` starts with `needle`, `needle` is removed from the
   *      beginning of `self`. Otherwise, `self` is unmodified.
   * @param self The slice to operate on.
   * @param needle The slice to search for.
   * @return `self`
   */
  function beyond(slice memory self, slice memory needle)
    internal
    pure
    returns (slice memory)
  {
    if (self._len < needle._len) {
      return self;
    }

    bool equal = true;
    if (self._ptr != needle._ptr) {
      assembly {
        let length := mload(needle)
        let selfptr := mload(add(self, 0x20))
        let needleptr := mload(add(needle, 0x20))
        equal := eq(keccak256(selfptr, length), keccak256(needleptr, length))
      }
    }

    if (equal) {
      self._len -= needle._len;
      self._ptr += needle._len;
    }

    return self;
  }

  /*
   * @dev Returns true if the slice ends with `needle`.
   * @param self The slice to operate on.
   * @param needle The slice to search for.
   * @return True if the slice starts with the provided text, false otherwise.
   */
  function endsWith(slice memory self, slice memory needle)
    internal
    pure
    returns (bool)
  {
    if (self._len < needle._len) {
      return false;
    }

    uint256 selfptr = self._ptr + self._len - needle._len;

    if (selfptr == needle._ptr) {
      return true;
    }

    bool equal;
    assembly {
      let length := mload(needle)
      let needleptr := mload(add(needle, 0x20))
      equal := eq(keccak256(selfptr, length), keccak256(needleptr, length))
    }

    return equal;
  }

  /*
   * @dev If `self` ends with `needle`, `needle` is removed from the
   *      end of `self`. Otherwise, `self` is unmodified.
   * @param self The slice to operate on.
   * @param needle The slice to search for.
   * @return `self`
   */
  function until(slice memory self, slice memory needle)
    internal
    pure
    returns (slice memory)
  {
    if (self._len < needle._len) {
      return self;
    }

    uint256 selfptr = self._ptr + self._len - needle._len;
    bool equal = true;
    if (selfptr != needle._ptr) {
      assembly {
        let length := mload(needle)
        let needleptr := mload(add(needle, 0x20))
        equal := eq(keccak256(selfptr, length), keccak256(needleptr, length))
      }
    }

    if (equal) {
      self._len -= needle._len;
    }

    return self;
  }

  // Returns the memory address of the first byte of the first occurrence of
  // `needle` in `self`, or the first byte after `self` if not found.
  function findPtr(
    uint256 selflen,
    uint256 selfptr,
    uint256 needlelen,
    uint256 needleptr
  ) private pure returns (uint256) {
    uint256 ptr = selfptr;
    uint256 idx;

    if (needlelen <= selflen) {
      if (needlelen <= 32) {
        bytes32 mask;
        if (needlelen > 0) {
          mask = bytes32(~(2**(8 * (32 - needlelen)) - 1));
        }

        bytes32 needledata;
        assembly {
          needledata := and(mload(needleptr), mask)
        }

        uint256 end = selfptr + selflen - needlelen;
        bytes32 ptrdata;
        assembly {
          ptrdata := and(mload(ptr), mask)
        }

        while (ptrdata != needledata) {
          if (ptr >= end) return selfptr + selflen;
          ptr++;
          assembly {
            ptrdata := and(mload(ptr), mask)
          }
        }
        return ptr;
      } else {
        // For long needles, use hashing
        bytes32 hash;
        assembly {
          hash := keccak256(needleptr, needlelen)
        }

        for (idx = 0; idx <= selflen - needlelen; idx++) {
          bytes32 testHash;
          assembly {
            testHash := keccak256(ptr, needlelen)
          }
          if (hash == testHash) return ptr;
          ptr += 1;
        }
      }
    }
    return selfptr + selflen;
  }

  // Returns the memory address of the first byte after the last occurrence of
  // `needle` in `self`, or the address of `self` if not found.
  function rfindPtr(
    uint256 selflen,
    uint256 selfptr,
    uint256 needlelen,
    uint256 needleptr
  ) private pure returns (uint256) {
    uint256 ptr;

    if (needlelen <= selflen) {
      if (needlelen <= 32) {
        bytes32 mask;
        if (needlelen > 0) {
          mask = bytes32(~(2**(8 * (32 - needlelen)) - 1));
        }

        bytes32 needledata;
        assembly {
          needledata := and(mload(needleptr), mask)
        }

        ptr = selfptr + selflen - needlelen;
        bytes32 ptrdata;
        assembly {
          ptrdata := and(mload(ptr), mask)
        }

        while (ptrdata != needledata) {
          if (ptr <= selfptr) return selfptr;
          ptr--;
          assembly {
            ptrdata := and(mload(ptr), mask)
          }
        }
        return ptr + needlelen;
      } else {
        // For long needles, use hashing
        bytes32 hash;
        assembly {
          hash := keccak256(needleptr, needlelen)
        }
        ptr = selfptr + (selflen - needlelen);
        while (ptr >= selfptr) {
          bytes32 testHash;
          assembly {
            testHash := keccak256(ptr, needlelen)
          }
          if (hash == testHash) return ptr + needlelen;
          ptr -= 1;
        }
      }
    }
    return selfptr;
  }

  /*
   * @dev Modifies `self` to contain everything from the first occurrence of
   *      `needle` to the end of the slice. `self` is set to the empty slice
   *      if `needle` is not found.
   * @param self The slice to search and modify.
   * @param needle The text to search for.
   * @return `self`.
   */
  function find(slice memory self, slice memory needle)
    internal
    pure
    returns (slice memory)
  {
    uint256 ptr = findPtr(self._len, self._ptr, needle._len, needle._ptr);
    self._len -= ptr - self._ptr;
    self._ptr = ptr;
    return self;
  }

  /*
   * @dev Modifies `self` to contain the part of the string from the start of
   *      `self` to the end of the first occurrence of `needle`. If `needle`
   *      is not found, `self` is set to the empty slice.
   * @param self The slice to search and modify.
   * @param needle The text to search for.
   * @return `self`.
   */
  function rfind(slice memory self, slice memory needle)
    internal
    pure
    returns (slice memory)
  {
    uint256 ptr = rfindPtr(self._len, self._ptr, needle._len, needle._ptr);
    self._len = ptr - self._ptr;
    return self;
  }

  /*
   * @dev Splits the slice, setting `self` to everything after the first
   *      occurrence of `needle`, and `token` to everything before it. If
   *      `needle` does not occur in `self`, `self` is set to the empty slice,
   *      and `token` is set to the entirety of `self`.
   * @param self The slice to split.
   * @param needle The text to search for in `self`.
   * @param token An output parameter to which the first token is written.
   * @return `token`.
   */
  function split(
    slice memory self,
    slice memory needle,
    slice memory token
  ) internal pure returns (slice memory) {
    uint256 ptr = findPtr(self._len, self._ptr, needle._len, needle._ptr);
    token._ptr = self._ptr;
    token._len = ptr - self._ptr;
    if (ptr == self._ptr + self._len) {
      // Not found
      self._len = 0;
    } else {
      self._len -= token._len + needle._len;
      self._ptr = ptr + needle._len;
    }
    return token;
  }

  /*
   * @dev Splits the slice, setting `self` to everything after the first
   *      occurrence of `needle`, and returning everything before it. If
   *      `needle` does not occur in `self`, `self` is set to the empty slice,
   *      and the entirety of `self` is returned.
   * @param self The slice to split.
   * @param needle The text to search for in `self`.
   * @return The part of `self` up to the first occurrence of `delim`.
   */
  function split(slice memory self, slice memory needle)
    internal
    pure
    returns (slice memory token)
  {
    split(self, needle, token);
  }

  /*
   * @dev Splits the slice, setting `self` to everything before the last
   *      occurrence of `needle`, and `token` to everything after it. If
   *      `needle` does not occur in `self`, `self` is set to the empty slice,
   *      and `token` is set to the entirety of `self`.
   * @param self The slice to split.
   * @param needle The text to search for in `self`.
   * @param token An output parameter to which the first token is written.
   * @return `token`.
   */
  function rsplit(
    slice memory self,
    slice memory needle,
    slice memory token
  ) internal pure returns (slice memory) {
    uint256 ptr = rfindPtr(self._len, self._ptr, needle._len, needle._ptr);
    token._ptr = ptr;
    token._len = self._len - (ptr - self._ptr);
    if (ptr == self._ptr) {
      // Not found
      self._len = 0;
    } else {
      self._len -= token._len + needle._len;
    }
    return token;
  }

  /*
   * @dev Splits the slice, setting `self` to everything before the last
   *      occurrence of `needle`, and returning everything after it. If
   *      `needle` does not occur in `self`, `self` is set to the empty slice,
   *      and the entirety of `self` is returned.
   * @param self The slice to split.
   * @param needle The text to search for in `self`.
   * @return The part of `self` after the last occurrence of `delim`.
   */
  function rsplit(slice memory self, slice memory needle)
    internal
    pure
    returns (slice memory token)
  {
    rsplit(self, needle, token);
  }

  /*
   * @dev Counts the number of nonoverlapping occurrences of `needle` in `self`.
   * @param self The slice to search.
   * @param needle The text to search for in `self`.
   * @return The number of occurrences of `needle` found in `self`.
   */
  function count(slice memory self, slice memory needle)
    internal
    pure
    returns (uint256 cnt)
  {
    uint256 ptr = findPtr(self._len, self._ptr, needle._len, needle._ptr) +
      needle._len;
    while (ptr <= self._ptr + self._len) {
      cnt++;
      ptr =
        findPtr(self._len - (ptr - self._ptr), ptr, needle._len, needle._ptr) +
        needle._len;
    }
  }

  /*
   * @dev Returns True if `self` contains `needle`.
   * @param self The slice to search.
   * @param needle The text to search for in `self`.
   * @return True if `needle` is found in `self`, false otherwise.
   */
  function contains(slice memory self, slice memory needle)
    internal
    pure
    returns (bool)
  {
    return
      rfindPtr(self._len, self._ptr, needle._len, needle._ptr) != self._ptr;
  }

  /*
   * @dev Returns a newly allocated string containing the concatenation of
   *      `self` and `other`.
   * @param self The first slice to concatenate.
   * @param other The second slice to concatenate.
   * @return The concatenation of the two strings.
   */
  function concat(slice memory self, slice memory other)
    internal
    pure
    returns (string memory)
  {
    string memory ret = new string(self._len + other._len);
    uint256 retptr;
    assembly {
      retptr := add(ret, 32)
    }
    memcpy(retptr, self._ptr, self._len);
    memcpy(retptr + self._len, other._ptr, other._len);
    return ret;
  }

  /*
   * @dev Joins an array of slices, using `self` as a delimiter, returning a
   *      newly allocated string.
   * @param self The delimiter to use.
   * @param parts A list of slices to join.
   * @return A newly allocated string containing all the slices in `parts`,
   *         joined with `self`.
   */
  function join(slice memory self, slice[] memory parts)
    internal
    pure
    returns (string memory)
  {
    if (parts.length == 0) return "";

    uint256 length = self._len * (parts.length - 1);
    for (uint256 i = 0; i < parts.length; i++) length += parts[i]._len;

    string memory ret = new string(length);
    uint256 retptr;
    assembly {
      retptr := add(ret, 32)
    }

    for (uint256 i = 0; i < parts.length; i++) {
      memcpy(retptr, parts[i]._ptr, parts[i]._len);
      retptr += parts[i]._len;
      if (i < parts.length - 1) {
        memcpy(retptr, self._ptr, self._len);
        retptr += self._len;
      }
    }

    return ret;
  }
}

// SPDX-License-Identifier: MIT

// sourced from https://github.com/pipermerriam/ethereum-datetime

pragma solidity ^0.8.0;

library DateTime {
  /*
   *  Date and Time utilities for ethereum contracts
   *
   */
  struct _DateTime {
    uint16 year;
    uint8 month;
    uint8 day;
    uint8 hour;
    uint8 minute;
    uint8 second;
    uint8 weekday;
  }

  uint256 constant DAY_IN_SECONDS = 86400;
  uint256 constant YEAR_IN_SECONDS = 31536000;
  uint256 constant LEAP_YEAR_IN_SECONDS = 31622400;

  uint256 constant HOUR_IN_SECONDS = 3600;
  uint256 constant MINUTE_IN_SECONDS = 60;

  uint16 constant ORIGIN_YEAR = 1970;

  function isLeapYear(uint16 year) internal pure returns (bool) {
    if (year % 4 != 0) {
      return false;
    }
    if (year % 100 != 0) {
      return true;
    }
    if (year % 400 != 0) {
      return false;
    }
    return true;
  }

  function leapYearsBefore(uint256 year) internal pure returns (uint256) {
    year -= 1;
    return year / 4 - year / 100 + year / 400;
  }

  function getDaysInMonth(uint8 month, uint16 year)
    internal
    pure
    returns (uint8)
  {
    if (
      month == 1 ||
      month == 3 ||
      month == 5 ||
      month == 7 ||
      month == 8 ||
      month == 10 ||
      month == 12
    ) {
      return 31;
    } else if (month == 4 || month == 6 || month == 9 || month == 11) {
      return 30;
    } else if (isLeapYear(year)) {
      return 29;
    } else {
      return 28;
    }
  }

  function parseTimestamp(uint256 timestamp)
    internal
    pure
    returns (_DateTime memory dt)
  {
    uint256 secondsAccountedFor = 0;
    uint256 buf;
    uint8 i;

    // Year
    dt.year = getYear(timestamp);
    buf = leapYearsBefore(dt.year) - leapYearsBefore(ORIGIN_YEAR);

    secondsAccountedFor += LEAP_YEAR_IN_SECONDS * buf;
    secondsAccountedFor += YEAR_IN_SECONDS * (dt.year - ORIGIN_YEAR - buf);

    // Month
    uint256 secondsInMonth;
    for (i = 1; i <= 12; i++) {
      secondsInMonth = DAY_IN_SECONDS * getDaysInMonth(i, dt.year);
      if (secondsInMonth + secondsAccountedFor > timestamp) {
        dt.month = i;
        break;
      }
      secondsAccountedFor += secondsInMonth;
    }

    // Day
    for (i = 1; i <= getDaysInMonth(dt.month, dt.year); i++) {
      if (DAY_IN_SECONDS + secondsAccountedFor > timestamp) {
        dt.day = i;
        break;
      }
      secondsAccountedFor += DAY_IN_SECONDS;
    }

    // Hour
    dt.hour = getHour(timestamp);

    // Minute
    dt.minute = getMinute(timestamp);

    // Second
    dt.second = getSecond(timestamp);

    // Day of week.
    dt.weekday = getWeekday(timestamp);
  }

  function getYear(uint256 timestamp) internal pure returns (uint16) {
    uint256 secondsAccountedFor = 0;
    uint16 year;
    uint256 numLeapYears;

    // Year
    year = uint16(ORIGIN_YEAR + timestamp / YEAR_IN_SECONDS);
    numLeapYears = leapYearsBefore(year) - leapYearsBefore(ORIGIN_YEAR);

    secondsAccountedFor += LEAP_YEAR_IN_SECONDS * numLeapYears;
    secondsAccountedFor +=
      YEAR_IN_SECONDS *
      (year - ORIGIN_YEAR - numLeapYears);

    while (secondsAccountedFor > timestamp) {
      if (isLeapYear(uint16(year - 1))) {
        secondsAccountedFor -= LEAP_YEAR_IN_SECONDS;
      } else {
        secondsAccountedFor -= YEAR_IN_SECONDS;
      }
      year -= 1;
    }
    return year;
  }

  function getMonth(uint256 timestamp) internal pure returns (uint8) {
    return parseTimestamp(timestamp).month;
  }

  function getDay(uint256 timestamp) internal pure returns (uint8) {
    return parseTimestamp(timestamp).day;
  }

  function getHour(uint256 timestamp) internal pure returns (uint8) {
    return uint8((timestamp / 60 / 60) % 24);
  }

  function getMinute(uint256 timestamp) internal pure returns (uint8) {
    return uint8((timestamp / 60) % 60);
  }

  function getSecond(uint256 timestamp) internal pure returns (uint8) {
    return uint8(timestamp % 60);
  }

  function getWeekday(uint256 timestamp) internal pure returns (uint8) {
    return uint8((timestamp / DAY_IN_SECONDS + 4) % 7);
  }

  function toTimestamp(
    uint16 year,
    uint8 month,
    uint8 day
  ) internal pure returns (uint256 timestamp) {
    return toTimestamp(year, month, day, 0, 0, 0);
  }

  function toTimestamp(
    uint16 year,
    uint8 month,
    uint8 day,
    uint8 hour
  ) internal pure returns (uint256 timestamp) {
    return toTimestamp(year, month, day, hour, 0, 0);
  }

  function toTimestamp(
    uint16 year,
    uint8 month,
    uint8 day,
    uint8 hour,
    uint8 minute
  ) internal pure returns (uint256 timestamp) {
    return toTimestamp(year, month, day, hour, minute, 0);
  }

  function toTimestamp(
    uint16 year,
    uint8 month,
    uint8 day,
    uint8 hour,
    uint8 minute,
    uint8 second
  ) internal pure returns (uint256 timestamp) {
    uint16 i;

    // Year
    for (i = ORIGIN_YEAR; i < year; i++) {
      if (isLeapYear(i)) {
        timestamp += LEAP_YEAR_IN_SECONDS;
      } else {
        timestamp += YEAR_IN_SECONDS;
      }
    }

    // Month
    uint8[12] memory monthDayCounts;
    monthDayCounts[0] = 31;
    if (isLeapYear(year)) {
      monthDayCounts[1] = 29;
    } else {
      monthDayCounts[1] = 28;
    }
    monthDayCounts[2] = 31;
    monthDayCounts[3] = 30;
    monthDayCounts[4] = 31;
    monthDayCounts[5] = 30;
    monthDayCounts[6] = 31;
    monthDayCounts[7] = 31;
    monthDayCounts[8] = 30;
    monthDayCounts[9] = 31;
    monthDayCounts[10] = 30;
    monthDayCounts[11] = 31;

    for (i = 1; i < month; i++) {
      timestamp += DAY_IN_SECONDS * monthDayCounts[i - 1];
    }

    // Day
    timestamp += DAY_IN_SECONDS * (day - 1);

    // Hour
    timestamp += HOUR_IN_SECONDS * (hour);

    // Minute
    timestamp += MINUTE_IN_SECONDS * (minute);

    // Second
    timestamp += second;

    return timestamp;
  }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

import "../upkeeps/CronUpkeep.sol";
import {Cron, Spec} from "../libraries/internal/Cron.sol";

/**
 * @title The CronUpkeepTestHelper contract
 * @notice This contract exposes core functionality of the CronUpkeep contract.
 * It is only intended for use in tests.
 */
contract CronUpkeepTestHelper is CronUpkeep {
  using Cron for Spec;
  using Cron for string;

  constructor(address owner, address delegate) CronUpkeep(owner, delegate) {}

  /**
   * @notice createCronJobFromString is a helper function for creating cron jobs
   * directly from strings. This is gas-intensive and shouldn't be done outside
   * of testing environments.
   */
  function createCronJobFromString(
    address target,
    bytes memory handler,
    string memory cronString
  ) external {
    Spec memory spec = cronString.toSpec();
    createCronJobFromSpec(target, handler, spec);
  }

  /**
   * @notice txCheckUpkeep is a helper function for sending real txs to the
   * checkUpkeep function. This allows us to do gas analysis on it.
   */
  function txCheckUpkeep(bytes calldata checkData) external {
    address(this).call(abi.encodeWithSelector(bytes4(keccak256("checkUpkeep(bytes)")), checkData));
  }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

import {Cron as CronInternal, Spec} from "../libraries/internal/Cron.sol";
import {Cron as CronExternal} from "../libraries/external/Cron.sol";

/**
 * @title The CronInternalTestHelper contract
 * @notice This contract exposes core functionality of the internal/Cron library.
 * It is only intended for use in tests.
 */
contract CronInternalTestHelper {
  /**
   * @notice Converts a cron string to a Spec, validates the spec, and encodes the spec.
   * This should only be called off-chain, as it is gas expensive!
   * @param cronString the cron string to convert and encode
   * @return the abi encoding of the Spec struct representing the cron string
   */
  function encodeCronString(string memory cronString) external pure returns (bytes memory) {
    return CronInternal.toEncodedSpec(cronString);
  }

  /**
   * @notice encodedSpecToString is a helper function for turning an
   * encoded spec back into a string. There is limited or no use for this outside
   * of tests.
   */
  function encodedSpecToString(bytes memory encodedSpec) public pure returns (string memory) {
    Spec memory spec = abi.decode(encodedSpec, (Spec));
    return CronInternal.toCronString(spec);
  }

  /**
   * @notice encodedSpecToString is a helper function for turning a string
   * into a spec struct.
   */
  function cronStringtoEncodedSpec(string memory cronString) public pure returns (Spec memory) {
    return CronInternal.toSpec(cronString);
  }

  /**
   * @notice calculateNextTick calculates the next time a cron job should "tick".
   * This should only be called off-chain, as it is gas expensive!
   * @param cronString the cron string to consider
   * @return the timestamp in UTC of the next "tick"
   */
  function calculateNextTick(string memory cronString) external view returns (uint256) {
    return CronInternal.nextTick(CronInternal.toSpec(cronString));
  }

  /**
   * @notice calculateLastTick calculates the last time a cron job "ticked".
   * This should only be called off-chain, as it is gas expensive!
   * @param cronString the cron string to consider
   * @return the timestamp in UTC of the last "tick"
   */
  function calculateLastTick(string memory cronString) external view returns (uint256) {
    return CronInternal.lastTick(CronInternal.toSpec(cronString));
  }
}

/**
 * @title The CronExternalTestHelper contract
 * @notice This contract exposes core functionality of the external/Cron library.
 * It is only intended for use in tests.
 */
contract CronExternalTestHelper {
  /**
   * @notice Converts a cron string to a Spec, validates the spec, and encodes the spec.
   * This should only be called off-chain, as it is gas expensive!
   * @param cronString the cron string to convert and encode
   * @return the abi encoding of the Spec struct representing the cron string
   */
  function encodeCronString(string memory cronString) external pure returns (bytes memory) {
    return CronExternal.toEncodedSpec(cronString);
  }

  /**
   * @notice encodedSpecToString is a helper function for turning an
   * encoded spec back into a string. There is limited or no use for this outside
   * of tests.
   */
  function encodedSpecToString(bytes memory encodedSpec) public pure returns (string memory) {
    Spec memory spec = abi.decode(encodedSpec, (Spec));
    return CronExternal.toCronString(spec);
  }

  /**
   * @notice encodedSpecToString is a helper function for turning a string
   * into a spec struct.
   */
  function cronStringtoEncodedSpec(string memory cronString) public pure returns (Spec memory) {
    return CronExternal.toSpec(cronString);
  }

  /**
   * @notice calculateNextTick calculates the next time a cron job should "tick".
   * This should only be called off-chain, as it is gas expensive!
   * @param cronString the cron string to consider
   * @return the timestamp in UTC of the next "tick"
   */
  function calculateNextTick(string memory cronString) external view returns (uint256) {
    return CronExternal.nextTick(CronExternal.toSpec(cronString));
  }

  /**
   * @notice calculateLastTick calculates the last time a cron job "ticked".
   * This should only be called off-chain, as it is gas expensive!
   * @param cronString the cron string to consider
   * @return the timestamp in UTC of the last "tick"
   */
  function calculateLastTick(string memory cronString) external view returns (uint256) {
    return CronExternal.lastTick(CronExternal.toSpec(cronString));
  }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Cron, Spec} from "../libraries/internal/Cron.sol";

/**
 * @title The CronUpkeepDelegate contract
 * @notice This contract serves as a delegate for all instances of CronUpkeep. Those contracts
 * delegate their checkUpkeep calls onto this contract. Utilizing this pattern reduces the size
 * of the CronUpkeep contracts.
 */
contract CronUpkeepDelegate {
  using EnumerableSet for EnumerableSet.UintSet;
  using Cron for Spec;

  address private s_owner; // from ConfirmedOwner
  address private s_delegate;
  uint256 private s_nextCronJobID;
  EnumerableSet.UintSet private s_activeCronJobIDs;
  mapping(uint256 => uint256) private s_lastRuns;
  mapping(uint256 => Spec) private s_specs;
  mapping(uint256 => address) private s_targets;
  mapping(uint256 => bytes) private s_handlers;

  /**
   * @notice Get the id of an eligible cron job
   * @return upkeepNeeded signals if upkeep is needed, performData is an abi encoding
   * of the id and "next tick" of the eligible cron job
   */
  function checkUpkeep(bytes calldata) external view returns (bool, bytes memory) {
    // DEV: start at a random spot in the list so that checks are
    // spread evenly among cron jobs
    uint256 numCrons = s_activeCronJobIDs.length();
    uint256 startIdx = block.number % numCrons;
    bool result;
    bytes memory payload;
    (result, payload) = checkInRange(startIdx, numCrons);
    if (result) {
      return (result, payload);
    }
    (result, payload) = checkInRange(0, startIdx);
    if (result) {
      return (result, payload);
    }
    return (false, bytes(""));
  }

  /**
   * @notice checks the cron jobs in a given range
   * @param start the starting id to check (inclusive)
   * @param end the ending id to check (exclusive)
   * @return upkeepNeeded signals if upkeep is needed, performData is an abi encoding
   * of the id and "next tick" of the elligible cron job
   */
  function checkInRange(uint256 start, uint256 end) private view returns (bool, bytes memory) {
    uint256 id;
    uint256 lastTick;
    for (uint256 idx = start; idx < end; idx++) {
      id = s_activeCronJobIDs.at(idx);
      lastTick = s_specs[id].lastTick();
      if (lastTick > s_lastRuns[id]) {
        return (true, abi.encode(id, lastTick, s_targets[id], s_handlers[id]));
      }
    }
  }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

import "../upkeeps/CronUpkeep.sol";
import "../upkeeps/CronUpkeepDelegate.sol";

/**
 * @title The CronUpkeepFactory contract
 * @notice This contract serves as a delegate for all instances of CronUpkeep. Those contracts
 * delegate their checkUpkeep calls onto this contract. Utilizing this pattern reduces the size
 * of the CronUpkeep contracts.
 */
contract CronUpkeepFactory {
  event NewCronUpkeepCreated(address upkeep, address owner);

  address private immutable s_cronDelegate;

  constructor() {
    s_cronDelegate = address(new CronUpkeepDelegate());
  }

  /**
   * @notice Creates a new CronUpkeep contract, with msg.sender as the owner
   */
  function newCronUpkeep() public {
    emit NewCronUpkeepCreated(address(new CronUpkeep(msg.sender, s_cronDelegate)), msg.sender);
  }

  /**
   * @notice Gets the address of the delegate contract
   * @return the address of the delegate contract
   */
  function cronDelegateAddress() public view returns (address) {
    return s_cronDelegate;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./KeeperBase.sol";
import "./interfaces/KeeperCompatibleInterface.sol";

abstract contract KeeperCompatible is KeeperBase, KeeperCompatibleInterface {}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../KeeperCompatible.sol";

contract KeeperCompatibleTestHelper is KeeperCompatible {
  function checkUpkeep(bytes calldata) external override returns (bool, bytes memory) {}

  function performUpkeep(bytes calldata) external override {}

  function testCannotExecute() public view cannotExecute {}
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

import "../upkeeps/EthBalanceMonitor.sol";

contract EthBalanceMonitorExposed is EthBalanceMonitor {
  constructor(address keeperRegistryAddress, uint256 minWaitPeriod)
    EthBalanceMonitor(keeperRegistryAddress, minWaitPeriod)
  {}

  function setLastTopUpXXXTestOnly(address target, uint56 lastTopUpTimestamp) external {
    s_targets[target].lastTopUpTimestamp = lastTopUpTimestamp;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../dev/VRF.sol";

/** ***********************************************************************
    @notice Testing harness for VRF.sol, exposing its internal methods. Not to
    @notice be used for production.
*/
contract VRFTestHelper is VRF {
  function bigModExp_(uint256 base, uint256 exponent) public view returns (uint256) {
    return super.bigModExp(base, exponent);
  }

  function squareRoot_(uint256 x) public view returns (uint256) {
    return super.squareRoot(x);
  }

  function ySquared_(uint256 x) public pure returns (uint256) {
    return super.ySquared(x);
  }

  function fieldHash_(bytes memory b) public pure returns (uint256) {
    return super.fieldHash(b);
  }

  function hashToCurve_(uint256[2] memory pk, uint256 x) public view returns (uint256[2] memory) {
    return super.hashToCurve(pk, x);
  }

  function ecmulVerify_(
    uint256[2] memory x,
    uint256 scalar,
    uint256[2] memory q
  ) public pure returns (bool) {
    return super.ecmulVerify(x, scalar, q);
  }

  function projectiveECAdd_(
    uint256 px,
    uint256 py,
    uint256 qx,
    uint256 qy
  )
    public
    pure
    returns (
      uint256,
      uint256,
      uint256
    )
  {
    return super.projectiveECAdd(px, py, qx, qy);
  }

  function affineECAdd_(
    uint256[2] memory p1,
    uint256[2] memory p2,
    uint256 invZ
  ) public pure returns (uint256[2] memory) {
    return super.affineECAdd(p1, p2, invZ);
  }

  function verifyLinearCombinationWithGenerator_(
    uint256 c,
    uint256[2] memory p,
    uint256 s,
    address lcWitness
  ) public pure returns (bool) {
    return super.verifyLinearCombinationWithGenerator(c, p, s, lcWitness);
  }

  function linearCombination_(
    uint256 c,
    uint256[2] memory p1,
    uint256[2] memory cp1Witness,
    uint256 s,
    uint256[2] memory p2,
    uint256[2] memory sp2Witness,
    uint256 zInv
  ) public pure returns (uint256[2] memory) {
    return super.linearCombination(c, p1, cp1Witness, s, p2, sp2Witness, zInv);
  }

  function scalarFromCurvePoints_(
    uint256[2] memory hash,
    uint256[2] memory pk,
    uint256[2] memory gamma,
    address uWitness,
    uint256[2] memory v
  ) public pure returns (uint256) {
    return super.scalarFromCurvePoints(hash, pk, gamma, uWitness, v);
  }

  function isOnCurve_(uint256[2] memory p) public pure returns (bool) {
    return super.isOnCurve(p);
  }

  function verifyVRFProof_(
    uint256[2] memory pk,
    uint256[2] memory gamma,
    uint256 c,
    uint256 s,
    uint256 seed,
    address uWitness,
    uint256[2] memory cGammaWitness,
    uint256[2] memory sHashWitness,
    uint256 zInv
  ) public view {
    super.verifyVRFProof(pk, gamma, c, s, seed, uWitness, cGammaWitness, sHashWitness, zInv);
  }

  function randomValueFromVRFProof_(Proof memory proof, uint256 seed) public view returns (uint256 output) {
    return super.randomValueFromVRFProof(proof, seed);
  }
}

// SPDX-License-Identifier: MIT
// An example VRF V1 consumer contract that can be triggered using a transferAndCall from the link
// contract.
pragma solidity ^0.8.0;

import "../VRFConsumerBase.sol";
import "../interfaces/ERC677ReceiverInterface.sol";

contract VRFOwnerlessConsumerExample is VRFConsumerBase, ERC677ReceiverInterface {
  uint256 public s_randomnessOutput;
  bytes32 public s_requestId;

  error OnlyCallableFromLink();

  constructor(address _vrfCoordinator, address _link) VRFConsumerBase(_vrfCoordinator, _link) {
    /* empty */
  }

  function fulfillRandomness(bytes32 requestId, uint256 _randomness) internal override {
    require(requestId == s_requestId, "request ID is incorrect");
    s_randomnessOutput = _randomness;
  }

  /**
   * @dev Creates a new randomness request. This function can only be used by calling
   * transferAndCall on the LinkToken contract.
   * @param _amount The amount of LINK transferred to pay for this request.
   * @param _data The data passed to transferAndCall on LinkToken. Must be an abi-encoded key hash.
   */
  function onTokenTransfer(
    address, /* sender */
    uint256 _amount,
    bytes calldata _data
  ) external override {
    if (msg.sender != address(LINK)) {
      revert OnlyCallableFromLink();
    }

    bytes32 keyHash = abi.decode(_data, (bytes32));
    s_requestId = requestRandomness(keyHash, _amount);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/LinkTokenInterface.sol";

import "./VRFRequestIDBase.sol";

/** ****************************************************************************
 * @notice Interface for contracts using VRF randomness
 * *****************************************************************************
 * @dev PURPOSE
 *
 * @dev Reggie the Random Oracle (not his real job) wants to provide randomness
 * @dev to Vera the verifier in such a way that Vera can be sure he's not
 * @dev making his output up to suit himself. Reggie provides Vera a public key
 * @dev to which he knows the secret key. Each time Vera provides a seed to
 * @dev Reggie, he gives back a value which is computed completely
 * @dev deterministically from the seed and the secret key.
 *
 * @dev Reggie provides a proof by which Vera can verify that the output was
 * @dev correctly computed once Reggie tells it to her, but without that proof,
 * @dev the output is indistinguishable to her from a uniform random sample
 * @dev from the output space.
 *
 * @dev The purpose of this contract is to make it easy for unrelated contracts
 * @dev to talk to Vera the verifier about the work Reggie is doing, to provide
 * @dev simple access to a verifiable source of randomness.
 * *****************************************************************************
 * @dev USAGE
 *
 * @dev Calling contracts must inherit from VRFConsumerBase, and can
 * @dev initialize VRFConsumerBase's attributes in their constructor as
 * @dev shown:
 *
 * @dev   contract VRFConsumer {
 * @dev     constructor(<other arguments>, address _vrfCoordinator, address _link)
 * @dev       VRFConsumerBase(_vrfCoordinator, _link) public {
 * @dev         <initialization with other arguments goes here>
 * @dev       }
 * @dev   }
 *
 * @dev The oracle will have given you an ID for the VRF keypair they have
 * @dev committed to (let's call it keyHash), and have told you the minimum LINK
 * @dev price for VRF service. Make sure your contract has sufficient LINK, and
 * @dev call requestRandomness(keyHash, fee, seed), where seed is the input you
 * @dev want to generate randomness from.
 *
 * @dev Once the VRFCoordinator has received and validated the oracle's response
 * @dev to your request, it will call your contract's fulfillRandomness method.
 *
 * @dev The randomness argument to fulfillRandomness is the actual random value
 * @dev generated from your seed.
 *
 * @dev The requestId argument is generated from the keyHash and the seed by
 * @dev makeRequestId(keyHash, seed). If your contract could have concurrent
 * @dev requests open, you can use the requestId to track which seed is
 * @dev associated with which randomness. See VRFRequestIDBase.sol for more
 * @dev details. (See "SECURITY CONSIDERATIONS" for principles to keep in mind,
 * @dev if your contract could have multiple requests in flight simultaneously.)
 *
 * @dev Colliding `requestId`s are cryptographically impossible as long as seeds
 * @dev differ. (Which is critical to making unpredictable randomness! See the
 * @dev next section.)
 *
 * *****************************************************************************
 * @dev SECURITY CONSIDERATIONS
 *
 * @dev A method with the ability to call your fulfillRandomness method directly
 * @dev could spoof a VRF response with any random value, so it's critical that
 * @dev it cannot be directly called by anything other than this base contract
 * @dev (specifically, by the VRFConsumerBase.rawFulfillRandomness method).
 *
 * @dev For your users to trust that your contract's random behavior is free
 * @dev from malicious interference, it's best if you can write it so that all
 * @dev behaviors implied by a VRF response are executed *during* your
 * @dev fulfillRandomness method. If your contract must store the response (or
 * @dev anything derived from it) and use it later, you must ensure that any
 * @dev user-significant behavior which depends on that stored value cannot be
 * @dev manipulated by a subsequent VRF request.
 *
 * @dev Similarly, both miners and the VRF oracle itself have some influence
 * @dev over the order in which VRF responses appear on the blockchain, so if
 * @dev your contract could have multiple VRF requests in flight simultaneously,
 * @dev you must ensure that the order in which the VRF responses arrive cannot
 * @dev be used to manipulate your contract's user-significant behavior.
 *
 * @dev Since the ultimate input to the VRF is mixed with the block hash of the
 * @dev block in which the request is made, user-provided seeds have no impact
 * @dev on its economic security properties. They are only included for API
 * @dev compatability with previous versions of this contract.
 *
 * @dev Since the block hash of the block which contains the requestRandomness
 * @dev call is mixed into the input to the VRF *last*, a sufficiently powerful
 * @dev miner could, in principle, fork the blockchain to evict the block
 * @dev containing the request, forcing the request to be included in a
 * @dev different block with a different hash, and therefore a different input
 * @dev to the VRF. However, such an attack would incur a substantial economic
 * @dev cost. This cost scales with the number of blocks the VRF oracle waits
 * @dev until it calls responds to a request.
 */
abstract contract VRFConsumerBase is VRFRequestIDBase {
  /**
   * @notice fulfillRandomness handles the VRF response. Your contract must
   * @notice implement it. See "SECURITY CONSIDERATIONS" above for important
   * @notice principles to keep in mind when implementing your fulfillRandomness
   * @notice method.
   *
   * @dev VRFConsumerBase expects its subcontracts to have a method with this
   * @dev signature, and will call it once it has verified the proof
   * @dev associated with the randomness. (It is triggered via a call to
   * @dev rawFulfillRandomness, below.)
   *
   * @param requestId The Id initially returned by requestRandomness
   * @param randomness the VRF output
   */
  function fulfillRandomness(bytes32 requestId, uint256 randomness) internal virtual;

  /**
   * @dev In order to keep backwards compatibility we have kept the user
   * seed field around. We remove the use of it because given that the blockhash
   * enters later, it overrides whatever randomness the used seed provides.
   * Given that it adds no security, and can easily lead to misunderstandings,
   * we have removed it from usage and can now provide a simpler API.
   */
  uint256 private constant USER_SEED_PLACEHOLDER = 0;

  /**
   * @notice requestRandomness initiates a request for VRF output given _seed
   *
   * @dev The fulfillRandomness method receives the output, once it's provided
   * @dev by the Oracle, and verified by the vrfCoordinator.
   *
   * @dev The _keyHash must already be registered with the VRFCoordinator, and
   * @dev the _fee must exceed the fee specified during registration of the
   * @dev _keyHash.
   *
   * @dev The _seed parameter is vestigial, and is kept only for API
   * @dev compatibility with older versions. It can't *hurt* to mix in some of
   * @dev your own randomness, here, but it's not necessary because the VRF
   * @dev oracle will mix the hash of the block containing your request into the
   * @dev VRF seed it ultimately uses.
   *
   * @param _keyHash ID of public key against which randomness is generated
   * @param _fee The amount of LINK to send with the request
   *
   * @return requestId unique ID for this request
   *
   * @dev The returned requestId can be used to distinguish responses to
   * @dev concurrent requests. It is passed as the first argument to
   * @dev fulfillRandomness.
   */
  function requestRandomness(bytes32 _keyHash, uint256 _fee) internal returns (bytes32 requestId) {
    LINK.transferAndCall(vrfCoordinator, _fee, abi.encode(_keyHash, USER_SEED_PLACEHOLDER));
    // This is the seed passed to VRFCoordinator. The oracle will mix this with
    // the hash of the block containing this request to obtain the seed/input
    // which is finally passed to the VRF cryptographic machinery.
    uint256 vRFSeed = makeVRFInputSeed(_keyHash, USER_SEED_PLACEHOLDER, address(this), nonces[_keyHash]);
    // nonces[_keyHash] must stay in sync with
    // VRFCoordinator.nonces[_keyHash][this], which was incremented by the above
    // successful LINK.transferAndCall (in VRFCoordinator.randomnessRequest).
    // This provides protection against the user repeating their input seed,
    // which would result in a predictable/duplicate output, if multiple such
    // requests appeared in the same block.
    nonces[_keyHash] = nonces[_keyHash] + 1;
    return makeRequestId(_keyHash, vRFSeed);
  }

  LinkTokenInterface internal immutable LINK;
  address private immutable vrfCoordinator;

  // Nonces for each VRF key from which randomness has been requested.
  //
  // Must stay in sync with VRFCoordinator[_keyHash][this]
  mapping(bytes32 => uint256) /* keyHash */ /* nonce */
    private nonces;

  /**
   * @param _vrfCoordinator address of VRFCoordinator contract
   * @param _link address of LINK token contract
   *
   * @dev https://docs.chain.link/docs/link-token-contracts
   */
  constructor(address _vrfCoordinator, address _link) {
    vrfCoordinator = _vrfCoordinator;
    LINK = LinkTokenInterface(_link);
  }

  // rawFulfillRandomness is called by VRFCoordinator when it receives a valid VRF
  // proof. rawFulfillRandomness then calls fulfillRandomness, after validating
  // the origin of the call
  function rawFulfillRandomness(bytes32 requestId, uint256 randomness) external {
    require(msg.sender == vrfCoordinator, "Only VRFCoordinator can fulfill");
    fulfillRandomness(requestId, randomness);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract VRFRequestIDBase {
  /**
   * @notice returns the seed which is actually input to the VRF coordinator
   *
   * @dev To prevent repetition of VRF output due to repetition of the
   * @dev user-supplied seed, that seed is combined in a hash with the
   * @dev user-specific nonce, and the address of the consuming contract. The
   * @dev risk of repetition is mostly mitigated by inclusion of a blockhash in
   * @dev the final seed, but the nonce does protect against repetition in
   * @dev requests which are included in a single block.
   *
   * @param _userSeed VRF seed input provided by user
   * @param _requester Address of the requesting contract
   * @param _nonce User-specific nonce at the time of the request
   */
  function makeVRFInputSeed(
    bytes32 _keyHash,
    uint256 _userSeed,
    address _requester,
    uint256 _nonce
  ) internal pure returns (uint256) {
    return uint256(keccak256(abi.encode(_keyHash, _userSeed, _requester, _nonce)));
  }

  /**
   * @notice Returns the id for this request
   * @param _keyHash The serviceAgreement ID to be used for this request
   * @param _vRFInputSeed The seed to be passed directly to the VRF
   * @return The id for this request
   *
   * @dev Note that _vRFInputSeed is not the seed passed by the consuming
   * @dev contract, but the one generated by makeVRFInputSeed
   */
  function makeRequestId(bytes32 _keyHash, uint256 _vRFInputSeed) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(_keyHash, _vRFInputSeed));
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/LinkTokenInterface.sol";
import "../VRFConsumerBase.sol";

contract VRFConsumer is VRFConsumerBase {
  uint256 public randomnessOutput;
  bytes32 public requestId;

  constructor(address vrfCoordinator, address link)
    // solhint-disable-next-line no-empty-blocks
    VRFConsumerBase(vrfCoordinator, link)
  {
    /* empty */
  }

  function fulfillRandomness(
    bytes32, /* requestId */
    uint256 randomness
  ) internal override {
    randomnessOutput = randomness;
    requestId = requestId;
  }

  function testRequestRandomness(bytes32 keyHash, uint256 fee) external returns (bytes32) {
    return requestRandomness(keyHash, fee);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../VRFRequestIDBase.sol";

contract VRFRequestIDBaseTestHelper is VRFRequestIDBase {
  function makeVRFInputSeed_(
    bytes32 _keyHash,
    uint256 _userSeed,
    address _requester,
    uint256 _nonce
  ) public pure returns (uint256) {
    return makeVRFInputSeed(_keyHash, _userSeed, _requester, _nonce);
  }

  function makeRequestId_(bytes32 _keyHash, uint256 _vRFInputSeed) public pure returns (bytes32) {
    return makeRequestId(_keyHash, _vRFInputSeed);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/LinkTokenInterface.sol";
import "../VRFConsumerBase.sol";

contract VRFCoordinatorMock {
  LinkTokenInterface public LINK;

  event RandomnessRequest(address indexed sender, bytes32 indexed keyHash, uint256 indexed seed);

  constructor(address linkAddress) public {
    LINK = LinkTokenInterface(linkAddress);
  }

  function onTokenTransfer(
    address sender,
    uint256 fee,
    bytes memory _data
  ) public onlyLINK {
    (bytes32 keyHash, uint256 seed) = abi.decode(_data, (bytes32, uint256));
    emit RandomnessRequest(sender, keyHash, seed);
  }

  function callBackWithRandomness(
    bytes32 requestId,
    uint256 randomness,
    address consumerContract
  ) public {
    VRFConsumerBase v;
    bytes memory resp = abi.encodeWithSelector(v.rawFulfillRandomness.selector, requestId, randomness);
    uint256 b = 206000;
    require(gasleft() >= b, "not enough gas for consumer");
    (bool success, ) = consumerContract.call(resp);
  }

  modifier onlyLINK() {
    require(msg.sender == address(LINK), "Must use LINK token");
    _;
  }
}