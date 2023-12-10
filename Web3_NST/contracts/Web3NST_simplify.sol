// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Simplified version of Web3NST, for demonstration purposes only, with functionalities limited to receiving and distributing money, and recording transactions.

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";

contract Web3NST_simplify is FunctionsClient, ConfirmedOwner {
    /* Chainlink Automation Functions */
    error NotAllowedCaller(
        address caller,
        address owner,
        address automationRegistry
    );
    error UnexpectedRequestID(bytes32 requestId);
    
    event Response(bytes32 indexed requestId, bytes response, bytes err);

    address public upkeepContract;
    bytes public request;
    uint64 public subscriptionId;
    uint32 public gasLimit;
    bytes32 public donID;
    bytes32 public s_lastRequestId;
    bytes public s_lastResponse;
    bytes public s_lastError;

    /// Web3NST
    // Error
    error Web3NST__NotOperator();
    error Web3NST__InsufficientFunds();
    error Web3NST__IncorrectAmount();

    /* Type declarations */
    // There are three main types of roles involved.
    enum StakeholderType {
        Operator,
        UnionMember,
        OtherStakeholders
    }

    /* State Variables */
    address private operatorAddress;
    uint256 private serviceFee;
    mapping (StakeholderType => uint256) private stakes;

    address[] private unionMembers;
    uint256 private totalUnionStakes;
    mapping (address => uint256) private unionMemberStakes;
    address private otherStakeholdersAddress;
    mapping (address => string) private metadata;

    uint256 private distributionFraction;
    uint256 private minimumWithdrawalAmount;

    // State variable used to prevent reentrancy attacks.
    bool private isDistributing = false;


    // Constructor
    constructor(
        address router, uint256 _serviceFee, address _otherStakeholdersAddress
    ) FunctionsClient(router) ConfirmedOwner(msg.sender) {
        operatorAddress = msg.sender;
        serviceFee = _serviceFee;
        minimumWithdrawalAmount = 1 ether;
        distributionFraction = 10;
        otherStakeholdersAddress = _otherStakeholdersAddress;
        stakes[StakeholderType.Operator] = 7;           // Operator 拿 7/10
        stakes[StakeholderType.UnionMember] = 2;        // UnionMember 拿 2/10
        stakes[StakeholderType.OtherStakeholders] = 1;  // OtherStakeholders 拿 1/10
    }

    /* Modifier */
    // modifier onlyOperator
    modifier onlyOperator() {
        if(msg.sender != operatorAddress){revert Web3NST__NotOperator();}
        _;
    }

    /* Chainlink Automation Functions */
    // Restricted to being called by the owner or the upkeepContract.
    modifier onlyAllowed() {
        if (msg.sender != owner() && msg.sender != upkeepContract)
            revert NotAllowedCaller(msg.sender, owner(), upkeepContract);
        _;
    }

    /* Chainlink Automation Functions */
    // Setting the upkeepContract, which is one of the authorizations for onlyAllowed.
    function setAutomationCronContract(
        address _upkeepContract
    ) external onlyOwner {
        upkeepContract = _upkeepContract;
    }

    /* Chainlink Automation Functions */
    // Configuring the detailed parameters of the request.
    function updateRequest(
        bytes memory _request,
        uint64 _subscriptionId,
        uint32 _gasLimit,
        bytes32 _donID
    ) external onlyOwner {
        request = _request;
        subscriptionId = _subscriptionId;
        gasLimit = _gasLimit;
        donID = _donID;
    }

    /* Chainlink Automation Functions */
    // Sending a pre-encoded CBOR request.
    function sendRequestCBOR()
        external
        onlyAllowed
        returns (bytes32 requestId)
    {
        s_lastRequestId = _sendRequest(
            request,
            subscriptionId,
            gasLimit,
            donID
        );
        return s_lastRequestId;
    }

    /* Chainlink Automation Functions */
    // Storing the result returned from the most recent response.
    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        if (s_lastRequestId != requestId) {
            revert UnexpectedRequestID(requestId);
        }
        s_lastResponse = response;
        s_lastError = err;
        emit Response(requestId, s_lastResponse, s_lastError);
        // Adding logic to handle the response.
        totalUnionStakes += uint256(bytes32(response));
        uint256 remainder = uint256(bytes32(response)) % unionMembers.length;
        uint256 distributedStake = uint256(bytes32(response)) / unionMembers.length;
        unionMemberStakes[unionMembers[0]] += remainder;
        for (uint i = 0; i < unionMembers.length; i++) {
            unionMemberStakes[unionMembers[i]] += distributedStake;
        }
    }

    /* Payment */
    // Event to notify the operator's server.
    event PaymentReceived(address sender, uint amount);

    // Event triggered upon receiving funds.
    function receivePayment() external payable {
        if(msg.value != serviceFee){revert Web3NST__IncorrectAmount();}
        emit PaymentReceived(msg.sender, msg.value);
    }

    /* Withdraw */
    function distributeFunds() public payable onlyOperator {
        // Logic to defend against reentrancy attacks.
        require(!isDistributing, "Distribution already in progress");
        isDistributing = true;

        uint256 distributedAmount  = address(this).balance;

        if(distributedAmount < minimumWithdrawalAmount){revert Web3NST__InsufficientFunds();}
        uint256 unionMembersAmount = distributedAmount * stakes[StakeholderType.UnionMember] / distributionFraction;
        uint256 otherStakeholdersAmount = distributedAmount * stakes[StakeholderType.OtherStakeholders] / distributionFraction;
        uint256 operatorAmount = distributedAmount * stakes[StakeholderType.Operator] / distributionFraction;

        for (uint i = 0; i < unionMembers.length; i++) {
            address unionMemberAddress = unionMembers[i];
            uint256 unionMemberStake = unionMemberStakes[unionMemberAddress];

            // Calculating the amount due to each member.
            uint256 unionMemberPayment = unionMembersAmount * unionMemberStake / totalUnionStakes;
            // If a member has no stake in the current distribution, skip to the next member's stake calculation.
            if (unionMemberPayment == 0) {continue;}

            // Sending funds to the member.
            (bool PayToUnionMember, ) = payable(unionMemberAddress).call{value: unionMemberPayment}("");
            unionMemberStakes[unionMemberAddress] = 0;
        }
        totalUnionStakes = 0;

        (bool PayToOtherStakeholders, ) = payable(otherStakeholdersAddress).call{value: otherStakeholdersAmount}("");
        (bool PayToOperatorContract, ) = payable(operatorAddress).call{value: operatorAmount}("");

        // Resetting the distribution state.
        isDistributing = false;
    }

    /* Getter */
    // get current service fee
    function getServiceFee() public view returns (uint256) {
        return serviceFee;
    }

    // get current MinimumWithdrawalAmount
    function getMinimumWithdrawalAmount() public view returns (uint256) {
        return minimumWithdrawalAmount;
    }

    // retrieve a union member's stake
    function retrieveUnionMemberStake(address _unionMemberAddress) public view returns (uint256) {
        return unionMemberStakes[_unionMemberAddress];
    }

    // retrieve total stakes
    function retrieveTotalUnionStakes() public view returns (uint256) {
        return totalUnionStakes;
    }

    // get a member's matadata
    // function getMetadata(address _address) public view returns (string memory) {
    //     return metadata[_address];
    // }

    /* Setter */
    // add a UnionMember
    function addUnionMember(address _unionMemberAddress) public onlyOperator {
        unionMembers.push(_unionMemberAddress);
        unionMemberStakes[_unionMemberAddress] = 0;
    }

    // set metadata
    function setMetadata(address _address, string memory _metadata) public onlyOperator {
        metadata[_address] = _metadata;
    }

    // set service fee
    function setServiceFee(uint256 _serviceFee) public onlyOperator {
        serviceFee = _serviceFee;
    }

    // set MinimumWithdrawalAmount
    function setMinimumWithdrawalAmount(uint256 _minimumWithdrawalAmount) public onlyOperator {
        minimumWithdrawalAmount = _minimumWithdrawalAmount;
    }

    // set a UnionMember's stake，for test
    function setUnionMemberStake(address _unionMemberAddress, uint256 _stake) public onlyOperator {
        unionMemberStakes[_unionMemberAddress] = _stake;
        totalUnionStakes = totalUnionStakes + _stake;
    }
}