// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/*

                                                                                                    
                              ..                                                                    
                 .:.      ..::.                                      ..                ..           
                 .==-. .::-=..                                 ...  ..-.              .:.           
                 :=++=:====..                                   .:===-=--:.   .:.....::-.           
                .:-+======..                                       :-=-=:.      ....:..-..          
              ::-========-:.                .:==:      =**#%@@@@%=..-=:---@@@+    .:::::....        
          .::-==========+#@@@@@@@@@@@@+  :%@@@@@@@@%:  .@@@@@@@@@@@@=:  .:@@@@%. .-----:            
             .....:==+==+#@@@@@@@@@@@@# =@@@@@=-+@@@@@. %@@*.....+@@@.    @@@@@@-... .-.            
       ..     .. .-+++-:::----=--#@@@@..@@@@      .%@@@.+@@@.     +@@@    *@@-*@@*.   ..            
        .:-. :.. .-++-:       ..%@@@%  #@@@.       .@@@@.@@@=     +@@@.   +@@# :@@@:                
         ::..... :-+-:        .@@@@#   %@@@         :@@@=*@@@@@@@@@@@@    =@@%  .%@@+               
         .:.:::-::--:.       .@@@@*    %@@@         .@@@@:@@@@@@@@@%:     :@@@..:-%@@%              
       .:..::--:..-:       .-@@@@+     #@@@:         %@@@:#@@@  :%@@@*.    @@@@@@@@@@@@:.           
      ......::.  .:        +@@@@=      *@@@#         #@@@-=@@@.   -@@@@-   %@@@@@@@@@@@@#.          
             :.  .       .*@@@@-       .@@@@-       .@@@@- @@@@.   .%@@@%. +@@@.      *@@@:         
             ..         .%@@@@:         *@@@@*.  .  #@@@@. =@@@:     -@@@@==@@@.       :@@@+        
                       .@@@@@.    .......*@@@@@@**%@@@@@=  :@@@%.      %@@@@@@@=  .....==%%*=       
                      .@@@@@%%@@@@@@@@@@-.=@@@@@@@@@@@@+.   %@@@:       =*+=-::.   ..-=====:..      
                      :@@@@@@@@@@@@@@@@@+=--+@@@@@@@@%.                             .=+=+-.         
                      -@@@@@@@@@@@@@%#*+:---======-::..                            :=-..-+:         
                      -=:.             ...:=------=====-:::..                     ..     .:.        
                                      .:-========---:.......                               .        
                                    .--======-====-:.                                               
                                  .--------:..--===::                                               
                                .::::....     .--==--                                               
                               ..               .--=-.                                              
                                                 .:--:                                              
                                                   .::.                                             
                                                    .:.                                             
                                                      .                                             
                                                                                                    
                                                                                                    
*/

import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IZora} from "./IZora.sol";

/// @notice Zora Token contract
contract Zora is IZora, ERC20, ERC20Permit, ERC20Votes, Initializable {
    /// @notice Account allowed to mint total supply and set the contract URI upon initialization
    address immutable initializerAccount;

    /// @notice Contract URI for token metadata
    /// @dev Set only during initialization and cannot be changed afterward
    string _contractURI;

    /// @notice Does not fully setup token but stores the user to execute setup at a later time.
    /// @param _initializerAccount Account to one-time initialize the contract and mint the supply.
    constructor(address _initializerAccount) ERC20("Zora", "ZORA") ERC20Permit("Zora") {
        require(_initializerAccount != address(0), InitializerCannotBeAddressZero());
        initializerAccount = _initializerAccount;
    }

    /**
     * @notice Mints all the supply to the given addresses, and sets the contract URI.
     * @dev This is not done in the constructor because we want to be able to mine for a deterministic address
     * without changing the creation code of the contract, which would be the case if these values were
     * hardcoded in the constructor.
     * @param tos array of recipient addresses
     * @param amounts array of amounts to mint
     * @param contractURI_ contract URI to set for the token
     */
    function initialize(address[] calldata tos, uint256[] calldata amounts, string memory contractURI_) public initializer {
        require(tos.length == amounts.length, InvalidInputLengths());
        require(msg.sender == initializerAccount, OnlyAdmin());
        require(bytes(contractURI_).length > 0, URINeedsToBeSet());

        _contractURI = contractURI_;

        for (uint256 i = 0; i < tos.length; i++) {
            _mint(tos[i], amounts[i]);
        }
    }

    /// @notice Implements IERC7572 for extended token metadata
    /// @return Contract URI set for the token
    function contractURI() external view returns (string memory) {
        return _contractURI;
    }

    /// @dev Needed to override this OZ function to allow for both ERC20 and ERC20Votes inheritance
    /// @notice No-op inheritance fix for allowing votes and permit functionality. The shared nonce behaves the same in this case.
    /// @param from transfer from address for transfer hook
    /// @param to transfer to address for transfer hook
    /// @param amount quantity to transfer for hook
    function _update(address from, address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._update(from, to, amount);
    }

    /// @dev Needed to override this OZ function to allow for both ERC20Permit and general OZ inheritance
    /// @notice No-op inheritance fix for allowing votes and permit functionality. The shared nonce behaves the same in this case.
    /// @param owner Owner to get the nonces from
    function nonces(address owner) public view virtual override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
