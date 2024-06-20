// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MetalAirdropFactory.sol";

interface IGasliteDrop {
    function airdropERC20(
        address _token,
        address[] calldata _addresses,
        uint256[] calldata _amounts,
        uint256 _totalAmount
    ) external payable;

    function airdropERC721(
        address _nft,
        address[] calldata _addresses,
        uint256[] calldata _tokenIds
    ) external payable;

    function airdropETH(address[] calldata _addresses, uint256[] calldata _amounts)
        external
        payable;
}

IGasliteDrop constant gasliteDrop = IGasliteDrop(0x09350F89e2D7B6e96bA730783c2d76137B045FEF);

contract AirdropFactory is MetalAirdropFactory {
    error INVALID_AIRDROP_RECIPIENTS();

    event DeploymentWithAirdrop(
        address indexed token,
        uint256 indexed lpTokenId,
        address[] recipients,
        string name,
        string symbol
    );

    constructor(address _owner) MetalAirdropFactory(_owner) {}

    function _getAirdropAddressAndAmounts(address[] calldata _addresses, uint256 _airdropSupply)
        internal
        pure
        returns (address[] memory, uint256[] memory)
    {
        // initialize the array
        address[] memory newAddresses =
            new address[](_addresses.length);

        // copy the calldata into memory
        for (uint256 i; i < _addresses.length; ++i) {
            newAddresses[i] = _addresses[i];
        }

        // initialize the amounts array
        uint256[] memory amounts = new uint256[](newAddresses.length);

        // figure how much should go to each owner
        uint256 fractionalAmount = _airdropSupply / newAddresses.length;

        // load up the amounts
        for (uint256 i; i < newAddresses.length; ++i) {
            amounts[i] = fractionalAmount;
        }

        return (newAddresses, amounts);
    }

    function deployAndAirdrop(
        string calldata name,
        string calldata symbol,
        uint256 _initialPricePerEth,
        uint256 _totalSupply,
        uint256 _minterSupply,
        uint256 _airdropSupply,
        address _minterAddress,
        address[] calldata _airdropAddresses
    ) public returns (InstantLiquidityToken, uint256) {
        // airdrop array needs at least one recipient
        if (_airdropAddresses.length < 1) revert INVALID_AIRDROP_RECIPIENTS();

        // determine pool amount
        uint256 poolSupply = _totalSupply - _minterSupply - _airdropSupply;

        //
        (InstantLiquidityToken token, uint256 lpTokenId) =
            deploy({_name: name, _symbol: symbol, _initialPricePerEth: _initialPricePerEth, _totalSupply: _totalSupply, _poolSupply: poolSupply});


        // After token initialization and pool creation, transfer to the optional minter address
        if (_minterSupply > 0) {
            InstantLiquidityToken(token).transfer(_minterAddress, _minterSupply);
        }

        // approve the airdrop amount
        token.approve({spender: address(gasliteDrop), value: _airdropSupply});

        (address[] memory recipients, uint256[] memory amounts) =
            _getAirdropAddressAndAmounts({_addresses: _airdropAddresses, _airdropSupply: _airdropSupply});

        // transfer the airdropSupply to airdropAddresses
        gasliteDrop.airdropERC20({
            _token: address(token),
            _addresses: _airdropAddresses,
            _amounts: amounts,
            _totalAmount: _airdropSupply
        });

        emit DeploymentWithAirdrop({
            token: address(token),
            lpTokenId: lpTokenId,
            recipients: _airdropAddresses,
            name: name,
            symbol: symbol
        });

        return (token, lpTokenId);
    }
}
