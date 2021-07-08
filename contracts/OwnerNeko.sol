// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

import { NEKOToken } from './NEKOToken.sol';
import { SafeMath } from './SafeMath.sol';

contract OwnerNeko {

    using SafeMath for uint256;

    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    string public constant name = 'Neko Mint';
    uint32 public constant LOCK_PERIOD = 48 hours;
    uint32 public constant PERIOD = 72 hours;
    uint256 public constant MAX_MINT_COUNT = 504000 * 10 ** 18;

    bytes32 public DOMAIN_SEPARATOR;

    address[] public permitOwners;
    uint256 public ownerCount;
    uint256 public ownerRight;

    uint public blockTimestampLast;

    uint256 public budgetMint;

    uint public blockTimestampLockLast;

    NEKOToken public neko;

    Data public data;

    mapping(address => uint256) public ownerNonce;

    enum Type { Empty, LockMint, UnLockMint, AddOwner, RemoveOwner, ChangeOwner, Recall }

    struct Data {
        address[] sigOwners;
        address spender;
        uint256 state;
    }

    event AddPermitOwners(address newOwner);

    event RemovePermitOwners(address oldOwner);

    event LockMint(uint256 amount);

    event UnLockMint(address spender);

    event ChangeOwner(address owner);

    event Recall(address owner, uint state);

    modifier CheckState(uint256 _state) {
        require(data.state == _state || data.state == uint(Type.Empty), "The last signature is not finished");
        _;
    }

    modifier CheckPrestrain() {
        require(blockTimestampLockLast == 0 || budgetMint == 0, "Prestrain cannot be repeated");
        _;
    }

    modifier CheckAddress(address _owner) {
        require(_owner != address(0), "Invalid address");
        _;
    }

    constructor
    (
        address _neko,
        address[] memory _owners
    ) {

        neko = NEKOToken(_neko);

        ownerCount = _owners.length;
        require(ownerCount > 0, "Owners exception");
        for (uint x = 0; x < ownerCount; x++) {
            require(_owners[x] != address(0), "Invalid owner");
            permitOwners.push(_owners[x]);
        }
        setOwenerRight();

        uint256 chainId;

        assembly {
            chainId := chainid()
        }

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
                keccak256(bytes(name)),
                keccak256(bytes('1')),
                chainId,
                address(this)
            )
        );
    }

    function getData() external view
    returns
    (
        address[] memory sigOwners,
        uint256 budgetmint,
        uint blockTimestamplockLast,
        address spender,
        uint256 state
    ) {
        sigOwners = data.sigOwners;
        budgetmint = budgetMint;
        blockTimestamplockLast = blockTimestampLockLast;
        spender = data.spender;
        state = data.state;
    }

    function setOwenerRight() internal {
        if (ownerCount == 1) {
            ownerRight = 1;
        } else {
            ownerRight = ownerCount.mul(2).div(3);
        }
    }

    function addPermitOwners
    (
        address owner,
        address spender,
        uint value,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external CheckAddress(owner) CheckState(uint(Type.AddOwner)) {
        require(!checkPermitOwners(spender), "Already existed");

        bool result = permit(uint(Type.AddOwner), owner, spender, value, deadline, v, r, s);
        if (result) {
            permitOwners.push(spender);
            ownerCount = permitOwners.length;
            setOwenerRight();

            delete data;

            emit AddPermitOwners(spender);
        }
    }

    function removePermitOwners
    (
        address owner,
        address spender,
        uint value,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external CheckState(uint(Type.RemoveOwner)) {
        require(ownerCount > 1, "Not least one");
        require(checkPermitOwners(spender), "Invalid owner");

        bool result = permit(uint(Type.RemoveOwner), owner, spender, value, deadline, v, r, s);
        if (result) {
            for (uint256 x = 0; x < ownerCount; x++) {
                if (permitOwners[x] == spender) {
                    for (uint i = x; i < ownerCount - 1; i++) {
                        permitOwners[i] = permitOwners[i + 1];
                    }
                    permitOwners.pop();
                    ownerCount = permitOwners.length;
                    setOwenerRight();

                    delete data;

                    emit RemovePermitOwners(spender);
                    break;
                }
            }
        }
    }

    function checkSigOwners (address[] memory owners, address owner, uint state) internal pure {
        uint length = owners.length;
        if (length > 0) {
            if (state != uint(Type.Recall)) {
                for (uint256 x = 0; x < length; x++) {
                    require(owners[x] != owner, "Already existed");
                }
            } else {
                uint count;
                for (uint256 x = 0; x < length; x++) {
                    if (owners[x] == owner) {
                        count++;
                    }
                }
                require(count == 1, "Abnormal error");
            }

        }
    }

    function checkPermitOwners (address owner) internal view returns (bool) {
        for (uint256 x = 0; x < permitOwners.length; x++) {
            if (permitOwners[x] == owner) {
                return true;
            }
        }
        return false;
    }

    function recallOwner (address owner) internal {
        for (uint256 x = 0; x < data.sigOwners.length; x++) {
            if (data.sigOwners[x] == owner) {
                for (uint i = x; i < data.sigOwners.length - 1; i++) {
                    data.sigOwners[i] = data.sigOwners[i + 1];
                }
                data.sigOwners.pop();
            }
        }
    }

    function permit
    (
        uint256 state,
        address owner,
        address spender,
        uint value,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal returns (bool) {
        require(deadline >= block.timestamp, "Invalid expiration");
        require(checkPermitOwners(owner), "Invalid owner");
        checkSigOwners(data.sigOwners, owner, state);
        bytes32 digest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, ownerNonce[owner], deadline))
            )
        );
        address recoveredAddress = ecrecover(digest, v, r, s);
        if (recoveredAddress != address(0) && recoveredAddress == owner ) {
            uint256 sigcount;
            if (state == uint(Type.LockMint)) {
                data.sigOwners.push(owner);
                sigcount = data.sigOwners.length;
                if (sigcount == 1) {
                    budgetMint = value;
                    data.state = state;
                } else {
                    require(budgetMint == value, "Check abnormal");
                }
            } else if (state == uint(Type.Recall)) {
                recallOwner(owner);
            } else {
                data.sigOwners.push(owner);
                sigcount = data.sigOwners.length;
                if (sigcount == 1) {
                    data.spender = spender;
                    data.state = state;
                } else {
                    require(data.spender == spender, "Check abnormal");
                }
            }
            ownerNonce[owner] = ownerNonce[owner].add(1);
            if (sigcount >= ownerRight) {
                return true;
            }
            return false;
        }
        revert("Permit failure");
    }

    function lockMint
    (
        address owner,
        address spender,
        uint value,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external CheckPrestrain CheckState(uint(Type.LockMint)) {
        require(value <= MAX_MINT_COUNT && value > 0, "Abnormal amount");
        uint256 timeElapsed = block.timestamp - blockTimestampLast;
        require(timeElapsed >= PERIOD, "No satisfaction time");

        bool result = permit(uint(Type.LockMint), owner, spender, value, deadline, v, r, s);
        if (result) {
            blockTimestampLockLast = block.timestamp;

            delete data;
            emit LockMint(value);
        }

    }

    function unlockMint
    (
        address owner,
        address spender,
        uint value,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external CheckAddress(spender) CheckState(uint(Type.UnLockMint)) {
        require(budgetMint > 0, "Abnormal amount");
        uint block_time = block.timestamp;
        uint256 timeElapsed = block_time - blockTimestampLockLast;
        require(timeElapsed >= LOCK_PERIOD, "No satisfaction time");

        bool result = permit(uint(Type.UnLockMint), owner, spender, value, deadline, v, r, s);
        if (result) {
            neko.mint(data.spender, budgetMint);

            delete data;

            blockTimestampLast = block_time;
            budgetMint = 0;
            blockTimestampLockLast = 0;

            emit UnLockMint(data.spender);
        }
    }

    function changeOwner
    (
        address owner,
        address spender,
        uint value,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external CheckAddress(owner) CheckState(uint(Type.ChangeOwner)) {
        require(address(this) != spender, "Invalid owner");

        bool result = permit(uint(Type.ChangeOwner), owner, spender, value, deadline, v, r, s);
        if (result) {
            neko.transferOwnership(spender);

            delete data;

            emit ChangeOwner(spender);
        }
    }

    function recall
    (
        uint state,
        address owner,
        address spender,
        uint value,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external CheckState(state) {

        permit(uint(Type.Recall), owner, spender, value, deadline, v, r, s);

        if (data.sigOwners.length == 0) {

            delete data;

            emit Recall(owner, state);
        }
    }

}
