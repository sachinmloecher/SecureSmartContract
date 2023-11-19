// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

contract SumGame {
    address payable playerA;
    address payable playerB;
    uint256 private playerABalance;
    uint256 private playerBBalance;
    bytes32 private playerAHash;
    bytes32 private playerBHash;
    uint32 public immutable minimumWei = 1000000000;
    uint8 private playerANumber;
    uint8 private playerBNumber;
    bool public gameState;
    bool public winnerPicked;
    bool public hashesSet;

    event WinnerPicked(address winner, uint8 winningAmount);
    event HashEntered(address player);
    event GameReset();
    event InvalidReveal(address player);

    modifier gameInProgress() {
        require(gameState, "Game not in progress");
        _;
    }

    modifier mustBePlayer() {
        require((msg.sender == playerA || msg.sender == playerB), "Must be a player");
        _;
    }


    function enter() external payable {
        require(!gameState, "Game in progress");
        address sender = msg.sender;
        uint256 value = msg.value;
        require(value >= minimumWei, "Payment less than minimum to play");
        require(sender != playerA, "Cannot enter twice");
        if (playerA == address(0)) {
            playerA = payable(sender);
            playerABalance = value;
        } else {
            playerB = payable(sender);
            playerBBalance = value;
            gameState = true;
        }
    }


    function enterHash(bytes32 hash) external mustBePlayer gameInProgress {
        bytes32 currentHash = (msg.sender == playerA) ? playerAHash : playerBHash;
        require(currentHash == bytes32(0), "Hash already set");
        require(hash != bytes32(0), "Invalid (default) hash");
        if (msg.sender == playerA) {
            playerAHash = hash;
        } else {
            playerBHash = hash;
        }
        emit HashEntered(msg.sender);

        // Set hashesSet to true if both players have entered their hashes
        if (playerAHash != bytes32(0) && playerBHash != bytes32(0)) {
            hashesSet = true;
        }
    }

    function validHash(uint8 number, uint256 nonce) private view returns (bool) {
        bytes32 hash = (msg.sender == playerA) ? playerAHash : playerBHash;
        return ((number > 0 && number < 101) && keccak256(abi.encodePacked(msg.sender, number, nonce)) == hash);
    }

    function revealHash(uint8 number, uint256 nonce) external mustBePlayer gameInProgress {
        require(hashesSet, "Hashes not submitted yet");
        bool isPlayerA = (msg.sender == playerA);
        uint8 currentNumber = (isPlayerA) ? playerANumber : playerBNumber;
        require(currentNumber < 1, "Number already revealed");
        uint8 otherNumber = (isPlayerA) ? playerBNumber : playerANumber;
        if (validHash(number, nonce)) {
            if (isPlayerA) {
                playerANumber = number;
            } else {
                playerBNumber = number;
            }
            if (otherNumber > 0) {
                pickWinner();
            }
        } else {
            emit InvalidReveal(msg.sender);
            restartGame();
        }
    }

    function restartGame() private {
        playerAHash = 0;
        playerBHash = 0;
        playerANumber = 0;
        playerBNumber = 0;
        hashesSet = false;
        emit GameReset();
    }

    function pickWinner() private {
        uint8 sum = playerANumber + playerBNumber;
        address winnerAddress;
        if (sum % 2 == 0){
            playerABalance += sum;
            playerBBalance -= sum;
            winnerAddress = playerA;
        } else {
            playerBBalance += sum;
            playerABalance -= sum;
            winnerAddress = playerB;
        }
        winnerPicked = true;
        emit WinnerPicked(winnerAddress, sum);
    }

    function getBalance() external view mustBePlayer returns (uint256) {
        if (msg.sender == playerA) {
            return playerABalance;
        } else {
            return playerBBalance;
        }
    }

    function withdraw() external mustBePlayer gameInProgress {
        require(winnerPicked, "Winner must be picked before you can withdraw.");
        uint256 withdrawingBalance = (msg.sender == playerA) ? playerABalance : playerBBalance;
        require(withdrawingBalance > 0, "Your balance is 0.");
        address payable withdrawingAddress = payable(msg.sender);

        if (msg.sender == playerA) {
            playerABalance = 0;
        } else {
            playerBBalance = 0;
        }
        withdrawingAddress.transfer(withdrawingBalance);

        if (playerABalance < 1 && playerBBalance < 1) {
            resetGame();
        }
    }

    function resetGame() private {
        playerABalance = 0;
        playerBBalance = 0;
        playerANumber = 0;
        playerBNumber = 0;
        playerAHash = bytes32(0);
        playerBHash = bytes32(0);
        playerA = payable(address(0));
        playerB = payable(address(0));
        gameState = false;
        winnerPicked = false;
        hashesSet = false;
        emit GameReset();
    }
}