//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract WastedCharacter is
    ERC721EnumerableUpgradeable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable
{
    using SafeMathUpgradeable for uint256;

    event CharacterCreated(address owner, uint256 characterId);
    event BlacklistWarrior(uint256 characterId, bool isLocked);
    event CharacterBought(address buyer, uint256 amount);

    uint256[] private _characters;
    uint256 public maxMint = 15000;
    uint256 public maxPerBought = 10;
    bool public paused = false;

    string private _uri;

    mapping(uint256 => bool) public blacklist;

    function initialize(string memory baseURI) public initializer {
        __ERC721_init_unchained("WastedCharacter", "WAC");
        _uri = baseURI;
    }

    function setMaxMint(uint256 _newMaxMint) external onlyOwner {
        require(_newMaxMint > _characters.length);
        maxMint = _newMaxMint;
    }

    function togglePaused() external onlyOwner {
        paused = !paused;
    }

    function setMaxPerBought(uint256 _newMaxPerBought) external onlyOwner {
        require(_newMaxPerBought > 0, "WAC: invalid");
        maxPerBought = _newMaxPerBought;
    }

    function addWarriorToBlacklist(uint256 characterId) external onlyOwner {
        require(characterId < _characters.length, "WAC: character invalid");
        blacklist[characterId] = true;

        emit BlacklistWarrior(characterId, true);
    }

    function removeWarriorFromBlacklist(uint256 characterId)
        external
        onlyOwner
    {
        require(characterId < _characters.length, "WAC: character invalid");
        blacklist[characterId] = false;
        emit BlacklistWarrior(characterId, false);
    }

    function setBaseURI(string memory baseURI) external onlyOwner {
        _uri = baseURI;
    }

    function buyCharacter(uint256 amount) external {
        require(_characters.length + amount < maxMint, "WAC: out of range");
        require(amount < maxPerBought, "WAC: not eligible");

        for (uint256 i = 0; i < amount; i++) {
            uint256 characterId = _createCharacter();
            _safeMint(msg.sender, characterId);
        }
    }

    function _baseURI() internal view override returns (string memory) {
        return _uri;
    }

    function _createCharacter() private returns (uint256 characterId) {
        _characters.push(0);
        characterId = _characters.length - 1;

        emit CharacterCreated(msg.sender, characterId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        require(!paused, "WAC: paused");
        require(blacklist[tokenId], "WAC: blacklisted");
    }
}
