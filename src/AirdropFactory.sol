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

    event DeploymentWithAirdrop(
        address indexed token,
        uint256 indexed lpTokenId,
        address[] recipients,
        string name,
        string symbol
    );

    constructor(address _owner) MetalAirdropFactory(_owner) {}

    function _getAirdropAmounts(address[] calldata _addresses, uint256 _airdropSupply)
        internal
        pure
        returns (uint256[] memory) {

        // initialize the amounts array
        uint256[] memory amounts = new uint256[](_addresses.length);

        // figure how much should go to each owner
        uint256 fractionalAmount = _airdropSupply / _addresses.length;

        // load up the amounts
        for (uint256 i; i < _addresses.length; ++i) {
            amounts[i] = fractionalAmount;
        }

        return amounts;
    }

    function deployAndAirdrop(
        string calldata _name,
        string calldata _symbol,
        uint256 _initialPricePerEth,
        uint256 _totalSupply,
        uint256 _minterSupply,
        uint256 _airdropSupply,
        address _minterAddress,
        address[] calldata _airdropAddresses
    ) public returns (InstantLiquidityToken, uint256) {
        // airdrop array needs at least one recipient
        if (_airdropAddresses.length == 0) revert("must specify recipient addresses");

        // determine pool amount
        uint256 poolSupply = _totalSupply - _minterSupply - _airdropSupply;

        //
        (InstantLiquidityToken token, uint256 lpTokenId) =
            deploy({_name: _name, _symbol: _symbol, _initialPricePerEth: _initialPricePerEth, _totalSupply: _totalSupply, _poolSupply: poolSupply});


        // After token initialization and pool creation, transfer to the optional minter address
        if (_minterSupply > 0) {
            InstantLiquidityToken(token).transfer(_minterAddress, _minterSupply);
        }

        // approve the airdrop amount
        token.approve({spender: address(gasliteDrop), value: _airdropSupply});

        uint256[] memory amounts =
            _getAirdropAmounts({_addresses: _airdropAddresses, _airdropSupply: _airdropSupply});

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
            name: _name,
            symbol: _symbol
        });

        return (token, lpTokenId);
    }
}
