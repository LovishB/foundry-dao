// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
 
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {GovernToken} from "../src/GovernToken.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {Box} from "../src/Box.sol";

contract GovernTokenDeploy is Script {
    // Governance parameters
    uint256 constant INITIAL_SUPPLY = 1_000_000 * 10**18; // 1 million tokens
    uint256 constant QUORUM_PERCENTAGE = 4; // 4% of token supply
    
    // User addresses
    address deployer = address(1);
    address user1 = address(100);
    address user2 = address(101);
    address user3 = address(102);
    address user4 = address(103);
    
    // Contracts
    GovernToken token;
    TimelockController timelock;
    MyGovernor governor;
    Box box;
    
    // Proposal information
    uint256 proposalId;
    bytes32 descriptionHash;
    bytes[] calldatas;
    address[] targets;
    uint256[] values;
    string description;
    
    function run() public {
        // Setup
        vm.startBroadcast(deployer);
        setupContracts();
        vm.stopBroadcast();
        
        // Distribute tokens and delegate
        distributeTokens();
        
        // Create proposal
        vm.startBroadcast(user1);
        createProposal();
        vm.stopBroadcast();
        
        // Check initial state
        // checkProposalState("Initial State");
        
        // Skip blocks to start voting
        vm.roll(block.number + governor.votingDelay() + 1);
        // checkProposalState("After Voting Delay");
        
        // Cast votes
        castVotes();
        
        // Check state during voting
        // checkProposalState("During Voting Period");
        
        // Skip blocks to end voting
        vm.roll(block.number + governor.votingPeriod() + 1);
        // checkProposalState("After Voting Period");
        
        // Queue the proposal
        vm.startBroadcast(deployer);
        queueProposal();
        vm.stopBroadcast();
        
        // Check state after queuing
        // checkProposalState("After Queuing");
        
        // Skip time to pass timelock
        vm.warp(block.timestamp + timelock.getMinDelay() + 1);
        
        // Execute the proposal
        vm.startBroadcast(deployer);
        executeProposal();
        vm.stopBroadcast();
        
        // Check state after execution
        // checkProposalState("After Execution");
        
        // Verify the change was successful
        console.log("Box owner before proposal execution:", box.owner());
        console.log("Timelock controller address:", address(timelock));
        console.log("Box value after proposal execution:", box.retrieve());
    }
    
    function setupContracts() private {
        // Deploy token
        token = new GovernToken();
        
        // Mint initial supply to deployer
        token.mint(deployer, INITIAL_SUPPLY);
        
        // Deploy timelock controller - use deployer as proposer and executor
        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = deployer;
        executors[0] = address(0); // Zero address means anyone can execute
        
        timelock = new TimelockController(
            1 days, // 1 day delay
            proposers,
            executors,
            deployer // admin
        );
        
        // Deploy governor
        governor = new MyGovernor(token, timelock);
        
        // Setup roles - grant proposer role to governor
        // timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        // timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        
        // // Revoke admin role from deployer and transfer to timelock
        // timelock.revokeRole(timelock.TIMELOCK_ADMIN_ROLE(), deployer);
        
        // Deploy Box contract
        box = new Box();
        
        console.log("Contracts deployed:");
        console.log("- Token:", address(token));
        console.log("- Timelock:", address(timelock));
        console.log("- Governor:", address(governor));
        console.log("- Box:", address(box));
    }
    
    function distributeTokens() private {
        // Distribute tokens to users
        vm.startBroadcast(deployer);
        
        uint256 userAmount = INITIAL_SUPPLY / 10; // 10% of total supply
        token.transfer(user1, userAmount);
        token.transfer(user2, userAmount);
        token.transfer(user3, userAmount);
        token.transfer(user4, userAmount);
        
        vm.stopBroadcast();
        
        // Users delegate their voting power to themselves
        vm.startBroadcast(user1);
        token.delegate(user1);
        vm.stopBroadcast();
        
        vm.startBroadcast(user2);
        token.delegate(user2);
        vm.stopBroadcast();
        
        vm.startBroadcast(user3);
        token.delegate(user3);
        vm.stopBroadcast();
        
        vm.startBroadcast(user4);
        token.delegate(user4);
        vm.stopBroadcast();
        
        vm.startBroadcast(deployer);
        token.delegate(deployer);
        vm.stopBroadcast();
        
        console.log("Tokens distributed:");
        console.log("- Deployer:", token.balanceOf(deployer));
        console.log("- User1:", token.balanceOf(user1));
        console.log("- User2:", token.balanceOf(user2));
        console.log("- User3:", token.balanceOf(user3));
        console.log("- User4:", token.balanceOf(user4));
    }
    
    function createProposal() private {
        // Prepare proposal to change the Box contract's value and transfer ownership to timelock
        targets = new address[](2);
        values = new uint256[](2);
        calldatas = new bytes[](2);
        
        // Action 1: Set the value to 42
        targets[0] = address(box);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(Box.store.selector, 42);
        
        // Action 2: Transfer ownership to timelock
        targets[1] = address(box);
        values[1] = 0;
        calldatas[1] = abi.encodeWithSelector(Box.transferOwnership.selector, address(timelock));
        
        // Create description
        description = "Proposal #1: Store 42 in the Box and transfer ownership to timelock";
        
        // Submit proposal
        proposalId = governor.propose(targets, values, calldatas, description);
        descriptionHash = keccak256(bytes(description));
        
        console.log("Proposal created:");
        console.log("- ID:", proposalId);
        console.log("- Description:", description);
        console.log("- Current block:", block.number);
        console.log("- Voting starts at block:", block.number + governor.votingDelay());
        console.log("- Voting ends at block:", block.number + governor.votingDelay() + governor.votingPeriod());
    }
    
    function castVotes() private {
        // User1 votes for the proposal
        vm.startBroadcast(user1);
        governor.castVote(proposalId, 1); // 1 = For
        vm.stopBroadcast();
        console.log("User1 voted: FOR");
        
        // User2 votes for the proposal
        vm.startBroadcast(user2);
        governor.castVote(proposalId, 1); // 1 = For
        vm.stopBroadcast();
        console.log("User2 voted: FOR");
        
        // User3 votes against the proposal
        vm.startBroadcast(user3);
        governor.castVote(proposalId, 0); // 0 = Against
        vm.stopBroadcast();
        console.log("User3 voted: AGAINST");
        
        // User4 abstains
        vm.startBroadcast(user4);
        governor.castVote(proposalId, 2); // 2 = Abstain
        vm.stopBroadcast();
        console.log("User4 voted: ABSTAIN");
    }
    
    function queueProposal() private {
        // Queue the proposal
        governor.queue(targets, values, calldatas, descriptionHash);
        console.log("Proposal queued");
    }
    
    function executeProposal() private {
        // Execute the proposal
        governor.execute(targets, values, calldatas, descriptionHash);
        console.log("Proposal executed");
    }
    
    // function checkProposalState(string memory stage) private view {
    //     MyGovernor.ProposalState state = governor.state(proposalId);
        
    //     // string memory stateStr;
    //     // if (state == MyGovernor.ProposalState.Pending) stateStr = "Pending";
    //     // else if (state == MyGovernor.ProposalState.Active) stateStr = "Active";
    //     // else if (state == MyGovernor.ProposalState.Canceled) stateStr = "Canceled";
    //     // else if (state == MyGovernor.ProposalState.Defeated) stateStr = "Defeated";
    //     // else if (state == MyGovernor.ProposalState.Succeeded) stateStr = "Succeeded";
    //     // else if (state == MyGovernor.ProposalState.Queued) stateStr = "Queued";
    //     // else if (state == MyGovernor.ProposalState.Expired) stateStr = "Expired";
    //     // else if (state == MyGovernor.ProposalState.Executed) stateStr = "Executed";
        
    //     console.log("State check - %s: %s (Block: %d)", state);
        
    //     // If in active voting state, check vote counts
    //         (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = governor.proposalVotes(proposalId);
    //         console.log("- Votes FOR: %d", forVotes);
    //         console.log("- Votes AGAINST: %d", againstVotes);
    //         console.log("- Votes ABSTAIN: %d", abstainVotes);
    //         console.log("- Quorum required: %d", governor.quorum(block.number - 1));
        
    // }
}