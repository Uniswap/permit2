from vyper.interfaces import ERC20

nonces: public(HashMap[address, uint256])
isOperator: public(HashMap[address, HashMap[address, bool]])
allowance: public(HashMap[address, HashMap[address, HashMap[address, uint256]]])

@external
def transferFrom(token: address, owner: address, to: address, amount: uint256):
    allowed: uint256 = self.allowance[owner][token][msg.sender]

    if allowed != MAX_UINT256:
        if allowed >= amount:
            # todo: vyper has safe math right?
            self.allowance[owner][token][msg.sender] = allowed - amount
        else:
            assert self.isOperator[owner][msg.sender], "APPROVE_ALL_REQUIRED"

    response: Bytes[32] = raw_call(
        token,
        concat(
            method_id("transferFrom(address,address,uint256)"),
            convert(owner, bytes32),
            convert(to, bytes32),
            convert(amount, bytes32),
        ),
        max_outsize=32,
    )

    if len(response) > 0: assert convert(response, bool), "TRANSFER_FROM_FAILED"

@external
def permit(token: address, owner: address, spender: address, amount: uint256, expiry: uint256, v: uint8, r: bytes32, s: bytes32):
    assert expiry >= block.timestamp, "PERMIT_DEADLINE_EXPIRED"

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
                    convert(expiry, bytes32),
                )
            )
        )
    )

    recoveredAddress: address = ecrecover(digest,
        convert(v, uint256),
        convert(r, uint256),
        convert(s, uint256)
    )

    assert recoveredAddress != ZERO_ADDRESS and recoveredAddress == owner, "INVALID_SIGNER"

    self.allowance[owner][token][spender] = amount
    self.nonces[owner] = unsafe_add(nonce, 1)

@external
def invalidateNonces(noncesToInvalidate: uint256):
    assert noncesToInvalidate < 2 ** 16

    self.nonces[msg.sender] += noncesToInvalidate

@external
def setOperator(operator: address, approved: bool):
    self.isOperator[msg.sender][operator] = approved

@external
def approve(token: address, spender: address, amount: uint256):
    self.allowance[msg.sender][token][spender] = amount

@view
@external
def DOMAIN_SEPARATOR(token: address) -> bytes32:
    return self.computeDomainSeperator(token)

@view
@internal
def computeDomainSeperator(token: address) -> bytes32:
    return keccak256(
        concat(
            keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
            keccak256(convert("Yearn Vault", Bytes[11])),
            keccak256(convert("1", Bytes[28])),
            convert(chain.id, bytes32),
            convert(token, bytes32)
        )
    )