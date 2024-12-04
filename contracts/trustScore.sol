// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ReputationStateMachine {

    function test() public pure returns (uint256) {
        return 1;
    }

    /******************************************************************** */
    /*                                                                    */
    /*                              States                                */
    /*                                                                    */
    /******************************************************************** */
    // States of the transaction
    enum State { Pending, Shipping, Delivered, Cancelled }

    event DebugUser(bool exists, address user);

    event OfferDeleted(uint256 offerID, address seller);

    event DebugOfferDeletion(uint256 offerID, uint256 allOffersLength);


    // Delivery states
    enum DeliveryState { Shipped, NotShippedMissingData, NotShippedDeliveryProblem }
    /******************************************************************** */
    /*                                                                    */
    /*                            Datastructs                             */
    /*                                                                    */
    /******************************************************************** */
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
        bool rated;
    }

    // Struct to store user reputation
    struct UserProfile {
        uint256 score;
        bool exists;
        bool isMarketplace;
        bool authenticated; //TBD using DID
        uint256 numberOfRatings;
    }

    // Struct to store offer details
    struct Offer {
        uint256 offerID;
        string item;
        uint256 price;
        string description;
        address seller;
        address buyer;
        bool buyerAccept;
    }

    /******************************************************************** */
    /*                                                                    */
    /*                       Mappings & DataLists                         */
    /*                                                                    */
    /******************************************************************** */
    // Mapping to store user reputation by their wallet address
    mapping(address => UserProfile) private users;

    mapping(uint256 => bool) private validOfferIDs;


    // Array to store all registered user addresses
    address[] private userAddresses;

    // Array to store all offers
    Offer[] private allOffers;

    // Mappings
    mapping(uint256 => Transaction) public transactions; // Map transaction IDs to transactions
    mapping(address => UserProfile) public reputations; // Map addresses to reputation scores

    uint256 public transactionCount;
    /******************************************************************** */
    /*                                                                    */
    /*                              EVENTS                                */
    /*                                                                    */
    /******************************************************************** */
    event TransactionInitiated(uint256 transactionId, address buyer, address seller, address marketplace);
    event PhaseUpdated(uint256 transactionId, State newState);
    event TransactionFinalized(uint256 transactionId, bool success);
    event RatingSubmitted(uint256 transactionId, address rater, uint8 rating, string review);
    event OfferCreated(address indexed seller, string item, uint256 price, string description);


    /******************************************************************** */
    /*                                                                    */
    /*                            Modifiers                               */
    /*                                                                    */
    /******************************************************************** */
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

    /******************************************************************** */
    /*                                                                    */
    /*                            Functions                               */
    /*                                                                    */
    /******************************************************************** */

    function registerUser(bool isMarketplace) public {
        emit DebugUser(users[msg.sender].exists, msg.sender);
        require(!users[msg.sender].exists, "User already registered");
        users[msg.sender] = UserProfile(0, true, isMarketplace, true, 0);
        userAddresses.push(msg.sender);
    }

    function isUserRegistered(address user) public view returns (bool) {
        return users[user].exists;
    }

    // Function to get the full list of registered users
    function getAllUsers() public view returns (address[] memory) {
        return userAddresses;
    }

    // Function to get the profile of a specific user by address
    function getUserProfile(address user) public view returns (uint256, bool) {
        require(users[user].exists, "User does not exist");
        
        UserProfile memory userProfile = users[user];
        
        return (
            userProfile.score,
            userProfile.isMarketplace
        );
    }

    // Retrieve the TrustScore of the user
    function getUserScore(address userAddress) public view returns (uint256) {
        require(users[userAddress].exists, "User does not exist");
        return users[userAddress].score;
    }

    
    // Function to get all offers
    function getFilteredOffers() public view returns (Offer[] memory) {
        uint count = 0;

        // Create a temporary array to hold filtered offers
        Offer[] memory tempOffers = new Offer[](allOffers.length);

        if (users[msg.sender].isMarketplace) {
            // For marketplaces, return offers where buyerAccept is true
            for (uint i = 0; i < allOffers.length; i++) {
                if (allOffers[i].buyerAccept) {
                    tempOffers[count] = allOffers[i];
                    count++;
                }
            }
        } else {
            // For non-marketplaces, return offers where the caller is the seller or buyerAccept is false
            for (uint i = 0; i < allOffers.length; i++) {
                if (allOffers[i].seller == msg.sender || !allOffers[i].buyerAccept) {
                    tempOffers[count] = allOffers[i];
                    count++;
                }
            }
        }

        // Resize the array to include only the filtered offers
        Offer[] memory filteredOffers = new Offer[](count);
        for (uint i = 0; i < count; i++) {
            filteredOffers[i] = tempOffers[i];
        }

        return filteredOffers;
    }


    // Function to create an offer
    function createOffer(string memory item, uint256 price, string memory description) public {
        require(users[msg.sender].exists, "User must be registered to create an offer");
        require(bytes(item).length > 0, "Item name cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");
        Offer memory newOffer = Offer({
            offerID: allOffers.length,
            item: item,
            price: price,
            description: description,
            seller: msg.sender,
            buyer: address(0), // Set buyer to the zero address initially
            buyerAccept: false
        });

        allOffers.push(newOffer);
        emit OfferCreated(msg.sender, item, price, description);
    }


    function acceptOffer(uint256 offerID) public {
        require(offerID < allOffers.length, "Invalid offer ID");
        Offer storage offerToAccept = allOffers[offerID];
        offerToAccept.buyerAccept = true;
        offerToAccept.buyer = msg.sender;
    }


    function deleteOffer(uint256 offerID) public {
        require(allOffers.length > 0, "No offers to delete"); // Ensure the array is not empty
        require(offerID < allOffers.length, "Invalid offer ID"); // Ensure the offerID is within bounds

        Offer memory offerToDelete = allOffers[offerID];
        require(
            msg.sender == offerToDelete.seller || users[msg.sender].isMarketplace,
            "Only the seller or marketplace can delete this offer"
        );

        // If offerID is not the last element, replace it with the last element
        if (offerID < allOffers.length - 1) {
            allOffers[offerID] = allOffers[allOffers.length - 1];
        }

        // Remove the last element
        allOffers.pop();

        emit OfferDeleted(offerID, offerToDelete.seller);
    }






  

    /******************************************************************** */
    /*                                                                    */
    /*                            PHASE MODEL                             */
    /*                                                                    */
    /******************************************************************** */
    // Initialize a transaction (Phase 1)
    function initiateTransaction(address buyer, address seller, uint256 offerID) public {
        // Check that the caller is a registered marketplace
        require(users[msg.sender].exists && users[msg.sender].isMarketplace, "Only a marketplace can initiate a transaction");

        // Increment the transaction count and create a new transaction ID
        transactionCount++;
        uint256 transactionId = transactionCount;

        // Create the new transaction
        transactions[transactionId] = Transaction({
            buyer: buyer,
            seller: seller,
            marketplace: msg.sender,
            startTime: block.timestamp,
            phase1EndTime: block.timestamp + 8 days,
            phase2EndTime: 0,
            phase3EndTime: 0,
            currentState: State.Pending,
            deliveryState: DeliveryState.Shipped,
            finalized: false,
            rated: false
        });

        // Delete the offer associated with the offerID
        deleteOffer(offerID);

        // Emit the TransactionInitiated event
        emit TransactionInitiated(transactionId, buyer, seller, msg.sender);
    }


    // Phase 2: Marketplace confirms shipping (seller needs to send shippingID to marketplace in real world scenario)
    function confirmShipping(uint256 transactionId, uint256 phase2Duration)
        public
        inState(transactionId, State.Pending)
        withinTime(transactions[transactionId].phase1EndTime)
    {
        require(msg.sender == transactions[transactionId].marketplace, "Only marketplace can confirm shipping initiation");
        transactions[transactionId].currentState = State.Shipping;
        transactions[transactionId].phase2EndTime = block.timestamp + phase2Duration;

        emit PhaseUpdated(transactionId, State.Shipping);
    }

    // Phase 3: Marketplace provides final shipping state
    function updateDeliveryState(uint256 transactionId, DeliveryState deliveryState, uint256 phase3Duration)
        public
        inState(transactionId, State.Shipping)
    {
        require(msg.sender == transactions[transactionId].marketplace, "Only marketplace can update delivery state");
        transactions[transactionId].deliveryState = deliveryState;
        transactions[transactionId].currentState = State.Delivered;
        transactions[transactionId].phase3EndTime = block.timestamp + phase3Duration;

        emit PhaseUpdated(transactionId, State.Delivered);
    }

    // Phase 4: Buyer confirms goods
    function confirmGoods(uint256 transactionId) 
        public 
        inState(transactionId, State.Delivered) 
        withinTime(transactions[transactionId].phase3EndTime) 
    {
        require(msg.sender == transactions[transactionId].buyer, "Only buyer can confirm goods");
        transactions[transactionId].finalized = true;

        emit TransactionFinalized(transactionId, true);
    }

    // Submit rating and review
    function submitRating(uint256 transactionId, uint8 rating, string calldata review) public {
        require(transactions[transactionId].finalized, "Transaction not finalized");
        require(!transactions[transactionId].rated, "Transaction already rated");
        require(rating >= 1 && rating <= 5, "Rating must be between 1 and 5");

        Transaction storage txn = transactions[transactionId];
        if (msg.sender == txn.buyer) {
            reputations[txn.seller].score += rating;
            reputations[txn.seller].numberOfRatings++;
        } else if (msg.sender == txn.seller) {
            reputations[txn.buyer].score += rating;
            reputations[txn.buyer].numberOfRatings++;
        } else {
            revert("Only buyer or seller can submit rating");
        }

        txn.rated = true;
        emit RatingSubmitted(transactionId, msg.sender, rating, review);
    }

    // Cancel a transaction
    function cancelTransaction(uint256 transactionId) public {
        Transaction storage txn = transactions[transactionId];
        txn.currentState = State.Cancelled;
        txn.finalized = true;

        emit TransactionFinalized(transactionId, false);
    }

    // Function to get the current phase/state of a transaction
    function getTransactionPhase(uint256 transactionId) public view returns (string memory) {
    require(transactions[transactionId].buyer != address(0), "Transaction does not exist");
    
    State currentState = transactions[transactionId].currentState;
    if (currentState == State.Pending) {
        return "Pending";
    } else if (currentState == State.Shipping) {
        return "Shipping";
    } else if (currentState == State.Delivered) {
        return "Delivered";
    } else if (currentState == State.Cancelled) {
        return "Cancelled";
    } else {
        return "Unknown";
    }
    }

}
 
