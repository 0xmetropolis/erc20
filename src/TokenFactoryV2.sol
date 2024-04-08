// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./TokenFactory.sol";

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

contract TokenFactoryV2 is TokenFactory {
    event DeploymentWithAirdrop(
        address indexed token,
        uint256 indexed lpTokenId,
        address[] recipients,
        string name,
        string symbol
    );

    constructor(address _owner) TokenFactory(_owner) {}

    function _getAddressAndAmounts(address owner, address[] calldata _addresses)
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
        uint256 fractionalAmount = OWNER_ALLOCATION / newAddresses.length;

        // load up the amounts
        for (uint256 i; i < newAddresses.length; ++i) {
            amounts[i] = fractionalAmount;
        }

        return (newAddresses, amounts);
    }

    function deployAndAirdrop(
        string calldata name,
        string calldata symbol,
        address[] calldata addresses
    ) public returns (InstantLiquidityToken, uint256) {
        // deploy the token
        (InstantLiquidityToken token, uint256 lpTokenId) =
            _deploy({_recipient: address(this), _name: name, _symbol: symbol});

        // approve the amount
        token.approve({spender: address(gasliteDrop), value: OWNER_ALLOCATION});

        (address[] memory recipients, uint256[] memory amounts) =
            _getAddressAndAmounts({owner: msg.sender, _addresses: addresses});

        // airdrop the token
        gasliteDrop.airdropERC20({
            _token: address(token),
            _addresses: recipients,
            _amounts: amounts,
            _totalAmount: OWNER_ALLOCATION
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
        address[] calldata addresses
    ) public returns (InstantLiquidityToken, uint256) {
        if (addresses.length == 0) revert("must specify recipient addresses");

        // deploy the token
        (InstantLiquidityToken token, uint256 lpTokenId) =
            _deploy({_recipient: address(this), _name: name, _symbol: symbol});

        // approve the amount
        token.approve({spender: address(gasliteDrop), value: OWNER_ALLOCATION});

        (address[] memory recipients, uint256[] memory amounts) =
            _getAddressAndAmounts({owner: address(0), _addresses: addresses});

        // airdrop the token
        gasliteDrop.airdropERC20({
            _token: address(token),
            _addresses: recipients,
            _amounts: amounts,
            _totalAmount: OWNER_ALLOCATION
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
