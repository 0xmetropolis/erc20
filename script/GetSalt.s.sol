// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// import {Script, console} from "forge-std/Script.sol";
// import {POOL_AMOUNT, OWNER_ALLOCATION} from "../src/Constants.sol";
// import {TokenFactory, InstantLiquidityToken} from "../src/TokenFactory.sol";

// contract GetSalt is Script {
//     function run() public {
//         TokenFactory factory = TokenFactory(0x83023728a09D0728052F4D187705Cb1f9D7B359A);
//         address weth = 0x4200000000000000000000000000000000000006;
//         vm.broadcast();

//         for (uint256 i; i < 10; i++) {
//             bytes32 salt = keccak256(abi.encode("SALT", i));
//             // address token = factory.clone(salt, "Token", "TKN");

//             bool tokenLessThanWeth = token < weth;

//             // console.log("ran times:", i + 1);
//             console.log("salt");
//             console.logBytes32(salt);

//             if (!tokenLessThanWeth) {
//                 console.log(unicode"token > weth ✅");
//             } else {
//                 console.log(unicode"token < weth ❌");
//             }

//             console.log("token", token);
//             // require(
//             //     InstantLiquidityToken(token).balanceOf(address(0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38))
//             //         == POOL_AMOUNT + OWNER_ALLOCATION,
//             //     "not transferred"
//             // );
//         }
//     }
// }
