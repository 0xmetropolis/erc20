// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MetalFunFactoryV2.sol";

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

contract AirdropFactory is MetalFunFactoryV2 {
    event DeploymentWithAirdrop(
        address indexed token,
        uint256 indexed lpTokenId,
        address[] recipients,
        string name,
        string symbol
    );

    constructor(address _owner) MetalFunFactoryV2(_owner) {}

    function _getAddressAndAmounts(address owner, address[] calldata _addresses, uint256 recipientSupply)
        internal
        pure
        returns (address[] memory, uint256[] memory)
    {
        bool includeOwner = owner != address(0);
        // initialize the array
        address[] memory newAddresses =
            new address[](includeOwner ? _addresses.length + 1 : _addresses.length);

        // copy the calldata into memory
        for (uint256 i; i < _addresses.length; ++i) {
            newAddresses[i] = _addresses[i];
        }

        // add the owner to the list
        if (includeOwner) newAddresses[_addresses.length] = owner;

        // initialize the amounts array
        uint256[] memory amounts = new uint256[](newAddresses.length);

        // figure how much should go to each owner
        uint256 fractionalAmount = recipientSupply / newAddresses.length;

        // load up the amounts
        for (uint256 i; i < newAddresses.length; ++i) {
            amounts[i] = fractionalAmount;
        }

        return (newAddresses, amounts);
    }

    function deployAndAirdrop(
        string calldata name,
        string calldata symbol,
        uint256 initialPricePerEth,
        uint256 totalSupply,
        uint256 recipientSupply,
        address[] calldata addresses
    ) public returns (InstantLiquidityToken, uint256) {
        // deploy the token, override the recipient for now
        (InstantLiquidityToken token, uint256 lpTokenId) =
            _deploy({_name: name, _symbol: symbol, _initialPricePerEth: initialPricePerEth, _totalSupply: totalSupply, _recipient: address(0), _recipientAmount: recipientSupply});

        // approve the amount
        token.approve({spender: address(gasliteDrop), value: recipientSupply});

        (address[] memory recipients, uint256[] memory amounts) =
            _getAddressAndAmounts({owner: msg.sender, _addresses: addresses, recipientSupply: recipientSupply});

        // airdrop the token
        gasliteDrop.airdropERC20({
            _token: address(token),
            _addresses: recipients,
            _amounts: amounts,
            _totalAmount: recipientSupply
        });

        emit DeploymentWithAirdrop({
            token: address(token),
            lpTokenId: lpTokenId,
            recipients: recipients,
            name: name,
            symbol: symbol
        });

        return (token, lpTokenId);
    }

    function deployAndAirdrop_noOwnerDistribution(
        string calldata name,
        string calldata symbol,
        uint256 initialPricePerEth,
        uint256 totalSupply,
        uint256 recipientSupply,
        address[] calldata addresses
    ) public returns (InstantLiquidityToken, uint256) {
        if (addresses.length == 0) revert("must specify recipient addresses");

        // deploy the token
        (InstantLiquidityToken token, uint256 lpTokenId) =
          _deploy({_name: name, _symbol: symbol, _initialPricePerEth: initialPricePerEth, _totalSupply: totalSupply, _recipient: address(0), _recipientAmount: recipientSupply});

        // approve the amount
        token.approve({spender: address(gasliteDrop), value: recipientSupply});

        (address[] memory recipients, uint256[] memory amounts) =
            _getAddressAndAmounts({owner: address(0), _addresses: addresses, recipientSupply: recipientSupply});

        // airdrop the token
        gasliteDrop.airdropERC20({
            _token: address(token),
            _addresses: recipients,
            _amounts: amounts,
            _totalAmount: recipientSupply
        });

        emit DeploymentWithAirdrop({
            token: address(token),
            lpTokenId: lpTokenId,
            recipients: recipients,
            name: name,
            symbol: symbol
        });

        return (token, lpTokenId);
    }
}
