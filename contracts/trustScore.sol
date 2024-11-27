    // SPDX-License-Identifier: MIT
    pragma solidity ^0.8.0;

    contract ReputationStateMachine {
        // States of the transaction
        enum State { Pending, Shipping, Delivered, Cancelled }

        // Delivery states
        enum DeliveryState { Shipped, NotShippedMissingData, NotShippedDeliveryProblem }

        // Struct to store transaction details
        struct Transaction {
            address buyer;
            address seller;
            address marketplace;
            uint256 startTime; // Start time of the transaction
            uint256 phase1EndTime; // End of Phase 1
            uint256 phase2EndTime; // End of Phase 2
            uint256 phase3EndTime; // End of Phase 3
            State currentState;
            DeliveryState deliveryState;
            bool finalized; // True if transaction is completed or cancelled
        }

        // Struct to store user reputation
        struct Reputation {
            uint score;
            bool exists;
        }

        // Mapping to store user reputation by their wallet address
        mapping(address => Reputation) private users;
        // Array to store all registered user addresses
        address[] private userAddresses;

        // Mappings
        mapping(uint256 => Transaction) public transactions; // Map transaction IDs to transactions
        mapping(address => Reputation) public reputations; // Map addresses to reputation scores

        uint256 public transactionCount;

        // Events
        event TransactionInitiated(uint256 transactionId, address buyer, address seller, address marketplace);
        event PhaseUpdated(uint256 transactionId, State newState);
        event TransactionFinalized(uint256 transactionId, bool success);

        // Modifier to check state
        modifier inState(uint256 transactionId, State requiredState) {
            require(transactions[transactionId].currentState == requiredState, "Invalid state for this action");
            _;
        }

        // Modifier to check timeframes
        modifier withinTime(uint256 deadline) {
            require(block.timestamp <= deadline, "Action is no longer allowed");
            _;
        }

        function registerUser() public {
        require(!users[msg.sender].exists, "User already registered");
        users[msg.sender] = Reputation(0, true); // Default score of 0
        userAddresses.push(msg.sender); // Add user address to the list
        }
        // Function to get the full list of registered users
        function getAllUsers() public view returns (address[] memory) {
            return userAddresses;
        }

        // Initialize a transaction (Phase 1)
        function initiateTransaction(address buyer, address seller ) public {
            transactionCount++;
            uint256 transactionId = transactionCount;

            transactions[transactionId] = Transaction({
                buyer: buyer,
                seller: seller,
                marketplace: msg.sender,
                startTime: block.timestamp,
                phase1EndTime: block.timestamp + 8 days,
                phase2EndTime: 0, // Will be set by the marketplace
                phase3EndTime: 0, // Will be set later
                currentState: State.Pending,
                deliveryState: DeliveryState.Shipped, // Default to shipped initially
                finalized: false
            });

            emit TransactionInitiated(transactionId,buyer, seller,  msg.sender);
        }

        // Phase 2: Marketplace confirms shipping
        function confirmShipping(uint256 transactionId, uint256 phase2Duration) 
            public 
            inState(transactionId, State.Pending) 
            withinTime(transactions[transactionId].phase1EndTime) 
        {
            require(msg.sender == transactions[transactionId].marketplace, "Only marketplace can confirm shipping");
            transactions[transactionId].currentState = State.Shipping;
            transactions[transactionId].phase2EndTime = block.timestamp + phase2Duration;

            emit PhaseUpdated(transactionId, State.Shipping);
        }

        // Phase 3: Marketplace provides final shipping state
        function updateDeliveryState(uint256 transactionId, DeliveryState deliveryState, uint256 phase3Duration)
            public
            inState(transactionId, State.Shipping)
            // withinTime(transactions[transactionId].phase2EndTime)
        {
            require(msg.sender == transactions[transactionId].marketplace, "Only marketplace can update delivery state");
            transactions[transactionId].deliveryState = deliveryState;
            transactions[transactionId].currentState = State.Delivered;
            transactions[transactionId].phase3EndTime = block.timestamp + phase3Duration;

            emit PhaseUpdated(transactionId, State.Delivered);
        }

        // Phase 4: Buyer confirms the quality of goods
        function BuyerConfirmGoods(uint256 transactionId, bool goodsOk) 
            public 
            inState(transactionId, State.Delivered) 
            // withinTime(transactions[transactionId].phase3EndTime) 
        {
            require(msg.sender == transactions[transactionId].buyer, "Only buyer can confirm goods");
            transactions[transactionId].finalized = true;

            // Update reputation scores
            if (goodsOk) {
                reputations[transactions[transactionId].buyer].score += 5;
                reputations[transactions[transactionId].seller].score += 5;
                reputations[transactions[transactionId].marketplace].score += 5;
            } else {
                reputations[transactions[transactionId].seller].score -= 5;
            }

            emit TransactionFinalized(transactionId, true);
        }

        /*
            Add a function for the Buyer to rate the Seller and Marketplace
        */

        /*
            Add a function for the Seller to rate the Buyer and Marketplace
        */

        // Cancel a transaction
        function cancelTransaction(uint256 transactionId) public {
            Transaction storage txn = transactions[transactionId];
            // require(block.timestamp > txn.phase1EndTime && txn.currentState == State.Pending, "Cannot cancel yet");

            txn.currentState = State.Cancelled;
            txn.finalized = true;

            emit TransactionFinalized(transactionId, false);
        }

        // // Get transaction details
        // function getTransaction(uint256 transactionId) public view returns (Transaction memory) {
        //     return transactions[transactionId];
        // }





        /*   THINGS TO WORK ON

        Priority 1:
                - Reputation Score function -> look at Thomas Code
                - Making the buyer and seller sign the contract with the marketplace
                    - Also look at how can we make the marketplace the only user that pays gas fees
                - SSI Integration


        Priority 2: 
                - User Interface
                - Time based cancelation
                - IPFS Integration
                    - If we add text review
        
        
        */
    }
