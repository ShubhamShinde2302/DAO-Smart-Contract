// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

contract DAO {
    struct Proposal {
        uint id;
        string description;
        uint amount;
        address payable receipient;
        uint votes;
        uint end;
        bool isExecuted;
    }

    mapping(address => bool) private isInvestor;
    mapping(address => uint) public numOfshares;
    mapping(address => mapping(uint => bool)) public isVoted;
    mapping(uint => Proposal) public proposals;
    
    address[] public investorsList;

    uint public totalShares;
    uint public availableFunds;
    uint public contributionTimeEnd;
    uint public nextProposalId;
    uint public voteTime;
    uint public quorum;
    address public manager;

    constructor(uint _contributionTimeEnd, uint _voteTime, uint _quorum) {
        require(_quorum > 0 && _quorum < 100, "Not valid values");
        contributionTimeEnd = block.timestamp + _contributionTimeEnd;
        voteTime = _voteTime;
        quorum = _quorum;
        manager = msg.sender;
    }

    modifier onlyInvestor() {
        require(isInvestor[msg.sender] == true, "You are not an investor");
        _;
    }

    modifier onlyManager() {
        require(manager == msg.sender, "You are not a manager");
        _;
    }

    function contribution() public payable {
        require(block.timestamp <= contributionTimeEnd, "Contribution time ended");
        require(msg.value > 0, "Send more than 0 ether");

        if (!isInvestor[msg.sender]) {
            investorsList.push(msg.sender);
        }

        isInvestor[msg.sender] = true;
        numOfshares[msg.sender] += msg.value;
        totalShares += msg.value;
        availableFunds += msg.value;
    }

    function reedemShare(uint amount) public onlyInvestor {
        require(numOfshares[msg.sender] >= amount, "You don't have enough shares");
        require(availableFunds >= amount, "Not enough funds");

        numOfshares[msg.sender] -= amount;

        if (numOfshares[msg.sender] == 0) {
            isInvestor[msg.sender] = false;
        }

        availableFunds -= amount;
        payable(msg.sender).transfer(amount);
    }

    function transferShare(uint amount, address to) public onlyInvestor {
        require(numOfshares[msg.sender] >= amount, "You don't have enough shares");

        numOfshares[msg.sender] -= amount;

        if (numOfshares[msg.sender] == 0) {
            isInvestor[msg.sender] = false;
        }

        numOfshares[to] += amount;

        if (!isInvestor[to]) {
            isInvestor[to] = true;
            investorsList.push(to);
        }
    }

    function createProposal(
        string calldata description,
        uint amount,
        address payable receipient
    ) public onlyManager {
        require(availableFunds >= amount, "Not enough funds");

        proposals[nextProposalId] = Proposal({
            id: nextProposalId,
            description: description,
            amount: amount,
            receipient: receipient,
            votes: 0,
            end: block.timestamp + voteTime,
            isExecuted: false
        });

        nextProposalId++;
    }

    function voteProposal(uint proposalId) public onlyInvestor {
        Proposal storage proposal = proposals[proposalId];

        require(!isVoted[msg.sender][proposalId], "You have already voted for this proposal");
        require(block.timestamp <= proposal.end, "Voting time ended");
        require(!proposal.isExecuted, "Proposal already executed");

        isVoted[msg.sender][proposalId] = true;
        proposal.votes += numOfshares[msg.sender];
    }

    function executeProposal(uint proposalId) public onlyManager {
        Proposal storage proposal = proposals[proposalId];

        require(!proposal.isExecuted, "Proposal already executed");
        require((proposal.votes * 100) / totalShares >= quorum, "Majority does not support");

        proposal.isExecuted = true;
        availableFunds -= proposal.amount;
        _transfer(proposal.amount, proposal.receipient);
    }

    function _transfer(uint amount, address payable receipient) private {
        receipient.transfer(amount);
    }

    function ProposalList() public view returns (Proposal[] memory) {
        Proposal[] memory arr = new Proposal[](nextProposalId);
        for (uint i = 0; i < nextProposalId; i++) {
            arr[i] = proposals[i];
        }
        return arr;
    }

    function InvestorList() public view returns (address[] memory) {
        return investorsList;
    }
}
