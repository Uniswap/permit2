from vyper.interfaces import ERC20

nonces: public(HashMap[address, uint256])
allowance: public(HashMap[address, HashMap[ERC20, HashMap[address, uint256]]])

@external
def transferFrom(token: ERC20, owner: address, to: address, amount: uint256):
    allowed: uint256 = self.allowance[owner][token][msg.sender]

    if allowed != max_value(uint256): self.allowance[owner][token][msg.sender] = allowed - amount

    token.transferFrom(owner, to, amount, default_return_value=True, skip_contract_check=True)

@external
def permit(token: ERC20, owner: address, spender: address, amount: uint256, expiry: uint256, v: uint8, r: bytes32, s: bytes32):
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

    assert recoveredAddress != empty(address) and recoveredAddress == owner, "INVALID_SIGNER"

    self.allowance[owner][token][spender] = amount
    self.nonces[owner] = unsafe_add(nonce, 1)

@external
def invalidateNonces(noncesToInvalidate: uint256):
    assert noncesToInvalidate < 2 ** 16

    self.nonces[msg.sender] += noncesToInvalidate

@external
def approve(token: ERC20, spender: address, amount: uint256):
    self.allowance[msg.sender][token][spender] = amount

@view
@external
def DOMAIN_SEPARATOR(token: ERC20) -> bytes32:
    return self.computeDomainSeperator(token)

@view
@internal
def computeDomainSeperator(token: ERC20) -> bytes32:
    return keccak256(
        concat(
            keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
            keccak256(convert("Yearn Vault", Bytes[11])), # todo rename
            keccak256(convert("1", Bytes[28])), # todo why so many bytes
            convert(chain.id, bytes32),
            convert(token, bytes32)
        )
    )