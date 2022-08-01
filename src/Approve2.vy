# @version 0.3.4

"""
@title Approve2
@license MIT
@author transmissions11 <t11s@paradigm.xyz>
@notice
    Backwards compatible, low-overhead,
    next generation token approval/meta-tx system.
"""

from vyper.interfaces import ERC20

# TODO: Hevm equivalence seems to not be working...? Is it storage layout or what?
# For reference, can test individual funcs with --sig "invalidateNonces(uint256)"

################################################################
#                           STORAGE                            #
################################################################

# Maps addresses to their current nonces. Used to prevent replay
# attacks and allow invalidating active permits via invalidateNonce.
nonces: public(HashMap[address, uint256])

# Maps users to tokens to spender addresses and how much they are
# approved to spend the amount of that token the user has approved.
allowance: public(HashMap[address, HashMap[ERC20, HashMap[address, uint256]]])

################################################################
#                      TRANSFERFROM LOGIC                      #
################################################################

@external
def transferFrom(token: ERC20, owner: address, to: address, amount: uint256):

    """
    @notice
        Transfer approved tokens from one address to another.
    @dev
        Requires either the from address to have approved at least the desired amount of
        tokens or msg.sender to be approved to manage all of the from addresses's tokens.
    @param token The token to transfer.
    @param owner The address to transfer from.
    @param to The address to transfer to.
    @param amount The amount of tokens to transfer.
    """

    allowed: uint256 = self.allowance[owner][token][msg.sender]

    if allowed != max_value(uint256): self.allowance[owner][token][msg.sender] = allowed - amount

    token.transferFrom(owner, to, amount, default_return_value=True, skip_contract_check=True)

################################################################
#                         PERMIT LOGIC                         #
################################################################

@external
def permit(token: ERC20, owner: address, spender: address, amount: uint256, deadline: uint256, v: uint8, r: bytes32, s: bytes32):

    """
    @notice
        Permit a user to spend an amount of another user's approved
        amount of the given token via the owner's EIP-712 signature.
    @dev May fail if the nonce was invalidated by invalidateNonce.
    @param token The token to permit spending.
    @param owner The user to permit spending from.
    @param spender The user to permit spending to.
    @param amount The amount to permit spending.
    @param deadline The timestamp after which the signature is no longer valid.
    @param v Must produce valid secp256k1 signature from the owner along with r and s.
    @param r Must produce valid secp256k1 signature from the owner along with v and s.
    @param s Must produce valid secp256k1 signature from the owner along with r and v.
    """

    assert deadline >= block.timestamp, "PERMIT_DEADLINE_EXPIRED"

    assert owner != empty(address), "INVALID_OWNER"

    nonce: uint256 = self.nonces[owner]

    digest: bytes32 = keccak256(
        concat(
            b'\x19\x01',
            self.computeDomainSeperator(token),
            keccak256(
                concat(
                    keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                    convert(owner, bytes32),
                    convert(spender, bytes32),
                    convert(amount, bytes32),
                    convert(nonce, bytes32),
                    convert(deadline, bytes32),
                )
            )
        )
    )

    recoveredAddress: address = ecrecover(digest,
        convert(v, uint256),
        convert(r, uint256),
        convert(s, uint256)
    )

    assert recoveredAddress == owner, "INVALID_SIGNER"

    self.allowance[owner][token][spender] = amount
    self.nonces[owner] = unsafe_add(nonce, 1)

################################################################
#                        LOCKDOWN LOGIC                        #
################################################################

struct Approval:
    token: ERC20
    spender: address

# TODO Test gas and if it works with non dyamic arrays.
@external
def lockdown(approvalsToRevoke: DynArray[Approval, 500], noncesToInvalidate: uint256):

    """
    @notice
        Enables performing a "lockdown" of the sender's Approve2
        identity by batch revoking approvals and invalidating nonces.
    @param approvalsToRevoke An array of approvals to revoke.
    @param noncesToInvalidate The number of nonces to invalidate.
    """
    # TODO Can we optimize the loop?
    for approval in approvalsToRevoke: self.allowance[msg.sender][approval.token][approval.spender] = 0

    # TODO Needs a 2**16 check.
    self.nonces[msg.sender] += noncesToInvalidate # TODO This can be made unsafe, overflow unlikely.

################################################################
#                   NONCE INVALIDATION LOGIC                   #
################################################################

@external
def invalidateNonces(noncesToInvalidate: uint256):

    """
    @notice
        Invalidate a specific number of nonces. Can be used
        to invalidate in-flight permits before they are executed.
    @param noncesToInvalidate The number of nonces to invalidate.
    """

    assert noncesToInvalidate < 2 ** 16 # TODO Do we need to extract this into a constant?

    self.nonces[msg.sender] += noncesToInvalidate # TODO This can be made unsafe, overflow unlikely.

################################################################
#                    MANUAL APPROVAL LOGIC                     #
################################################################

@external
def approve(token: ERC20, spender: address, amount: uint256):

    """
    @notice
        Manually approve a spender to transfer a specific
        amount of a specific ERC20 token from the sender.
    @param token The token to approve.
    @param spender The spender address to approve.
    @param amount The amount of the token to approve.
    """

    self.allowance[msg.sender][token][spender] = amount

################################################################
#                    DOMAIN SEPERATOR LOGIC                    #
################################################################

@view
@external
def DOMAIN_SEPARATOR(token: ERC20) -> bytes32:

    """
    @notice
        The EIP-712 "domain separator" the contract
        will use when validating signatures for a given token.
    @param token The token to get the domain separator for.
    """

    return self.computeDomainSeperator(token)

@view
@internal
def computeDomainSeperator(token: ERC20) -> bytes32:
    return keccak256(
        _abi_encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256("Approve2"),
            keccak256("1"),
            chain.id,
            token
        )
    )