// pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/utils/math/SafeMath.sol";
// import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// import "./utils/TokenHelper.sol";
// import "./interfaces/IWastedStakingToken.sol";

// contract WastedStakingToken is
//     IWastedStakingToken,
//     TokenHelper,
//     IERC721Receiver,
//     ReentrancyGuard,
//     Ownable
// {
//     using SafeMath for uint256;

//     WastedPool[] public _pools;

//     constructor() {}

//     function addPool(string name,uint256 warriorRequirement, uint256 tokenRequirement, uint256 totalReward, uint256 endTime, uint256 startTime ) external onlyOwner {
//         emit Pool(string name, uint256 warriorRequirement, uint256 tokenRequirement, uint256 totalReward, uint256 endTime, uint256 startTime);
//     }

//     function _calculateAPR() private {}

//     function onERC721Received(
//         address,
//         address,
//         uint256,
//         bytes calldata
//     ) external override returns (bytes4) {
//         return
//             bytes4(
//                 keccak256("onERC721Received(address,address,uint256,bytes)")
//             );
//     }
// }
