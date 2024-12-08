// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ReputationStateMachine {

    /******************************************************************** */
    /*                                                                    */
    /*                              States                                */
    /*                                                                    */
    /******************************************************************** */
    // Delivery states
    enum DeliveryState {NotShipped, Shipped, NotShippedMissingData, NotShippedDeliveryProblem }


    /******************************************************************** */
    /*                                                                    */
    /*                            Datastructs                             */
    /*                                                                    */
    /******************************************************************** */
    // Struct to store user profile
    struct UserProfile {
        uint256 ratingSum;
        uint256 ratingCount;
        bool exists;
        bool isMarketplace;
        bool authenticated;
    }

    // Struct to store transaction details
    struct Transaction {
        uint256 transactionID;
        address buyer;
        address seller;
        address marketplace;
        uint256 startTime; // Start time of the transaction
        uint256 phase1EndTime; // End of Phase 1
        uint256 phase2EndTime; // End of Phase 2
        uint256 phase3EndTime; // End of Phase 3
        uint256 phaseEndTime; // End of the current phase
        bool buyerRated; // To ensure rating happens only once per participant
        bool sellerRated;
        bool marketplaceRatedByBuyer;
        bool marketplaceRatedBySeller;        
        uint256 phase; // 1: Initiated, 2: Shipping, 3: Confirming, 4: Finalized
        DeliveryState deliveryState;
        bool finalized; // True if transaction is completed or cancelled

    }

    // Struct to store offer details
    struct Offer {
        uint256 offerID;
        string item;
        uint256 price;
        string description;
        address seller;
        address buyer;
        address marketplace;
        bool buyerAccept;
        bool valid;
    }

    /******************************************************************** */
    /*                                                                    */
    /*                       Mappings & DataLists                         */
    /*                                                                    */
    /******************************************************************** */
    // Mapping to store user reputation by their wallet address
    mapping(address => UserProfile) private users;

    // Array to store all registered user addresses
    address[] private userAddresses;

    // Array to store all offers
    Offer[] private allOffers;

    // Array to store all Transactions
    Transaction[] private allTransactions;


    /******************************************************************** */
    /*                                                                    */
    /*                              EVENTS                                */
    /*                                                                    */
    /******************************************************************** */
    event TransactionInitiated(uint256 transactionId, address buyer, address seller, address marketplace);
    event TransactionFinalized(uint256 transactionId, bool success);
    event TransactionCanceled(uint256 transactionId, address canceledBy); 
    event RatingSubmitted(uint256 transactionId, address rater, uint8 rating, string review);
    event OfferCreated(address indexed seller, string item, uint256 price, string description);


    /******************************************************************** */
    /*                                                                    */
    /*                            Modifiers                               */
    /*                                                                    */
    /******************************************************************** */
    modifier inState(uint256 transactionId, uint256 phase) {
        require(allTransactions[transactionId].phase == phase, "Invalid state");
        _;
    }
    modifier withinTime(uint256 endTime) {
        require(block.timestamp <= endTime, "Time limit exceeded");
        _;
    }


    /******************************************************************** */
    /*                                                                    */
    /*                            Functions                               */
    /*                                                                    */
    /******************************************************************** */
    function registerUser(bool isMarketplace) public {
        require(!users[msg.sender].exists, "User already registered");
        users[msg.sender] = UserProfile(0, 0, true, isMarketplace, true);
        userAddresses.push(msg.sender);
    }

    function isUserRegistered(address user) public view returns (bool) {
        return users[user].exists;
    }

    // Temporary struct to include user address with their profile
    struct UserWithAddress {
        address userAddress;
        uint256 ratingSum;
        uint256 ratingCount;
        bool exists;
        bool isMarketplace;
        bool authenticated;
    }

    // Function to get all registered users with their profiles and addresses
    function getAllUsers() public view returns (UserWithAddress[] memory) {
        uint256 totalUsers = userAddresses.length;
        UserWithAddress[] memory usersWithAddresses = new UserWithAddress[](totalUsers);

        for (uint256 i = 0; i < totalUsers; i++) {
            address userAddress = userAddresses[i];
            UserProfile memory profile = getUserProfile(userAddress);

            usersWithAddresses[i] = UserWithAddress({
                userAddress: userAddress,
                ratingSum: profile.ratingSum,
                ratingCount: profile.ratingCount,
                exists: profile.exists,
                isMarketplace: profile.isMarketplace,
                authenticated: profile.authenticated
            });
        }

        return usersWithAddresses;
    }

    // Function to get the profile of a specific user by address
    function getUserProfile(address user) public view returns (UserProfile memory) {
        require(users[user].exists, "User does not exist");
        
        UserProfile memory userProfile = users[user];
        
        return userProfile;
    }


    // Function to get all offers
    function getFilteredOffers() public view returns (Offer[] memory) {
        uint count = 0;

        // Create a temporary array to hold filtered offers
        Offer[] memory tempOffers = new Offer[](allOffers.length);

        /*         if (users[msg.sender].isMarketplace) {
                // For marketplaces, return offers where buyerAccept is true
                for (uint i = 0; i < allOffers.length; i++) {
                    if (allOffers[i].buyerAccept && allOffers[i].valid) {
                        tempOffers[count] = allOffers[i];
                        count++;
                    }
                }
            } else {
                // For non-marketplaces, return offers where the caller is the seller or buyerAccept is false
                for (uint i = 0; i < allOffers.length; i++) {
                    if (allOffers[i].valid) {
                        tempOffers[count] = allOffers[i];
                        count++;
                    }
                }
            } 
        */

        for (uint i = 0; i < allOffers.length; i++) {
            if (allOffers[i].valid) {
                tempOffers[count] = allOffers[i];
                count++;
            }
        }

        // Resize the array to include only the filtered offers
        Offer[] memory filteredOffers = new Offer[](count);
        for (uint i = 0; i < count; i++) {
            filteredOffers[i] = tempOffers[i];
        }

        return filteredOffers;
    }

    function getOfferCount() public view returns (uint256) {
        return allOffers.length;
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
            marketplace: address(0), // Set marketplace to the zero address initially;
            buyerAccept: false,
            valid: true
        });

        allOffers.push(newOffer);
        emit OfferCreated(msg.sender, item, price, description);
    }

    function acceptOffer(uint256 offerID) public {
        require(offerID < allOffers.length, "Invalid offer ID");
        allOffers[offerID].buyerAccept = true;
        allOffers[offerID].buyer = msg.sender;
    }

    function deleteOffer(uint256 offerID) public {
        require(allOffers.length > 0, "No offers to delete"); // Ensure the array is not empty
        require(offerID < allOffers.length, "Invalid offer ID"); // Ensure the offerID is within bounds

        allOffers[offerID].valid = false;
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

        // Create the new transaction
        Transaction memory transaction = Transaction({
            transactionID: offerID,
            buyer: buyer,
            seller: seller,
            marketplace: msg.sender,
            startTime: block.timestamp,
            phase1EndTime: block.timestamp + 8 days,
            phase2EndTime: 0,
            phase3EndTime: 14,
            phaseEndTime: block.timestamp + 8 days, // Deadline for the current phase
            deliveryState: DeliveryState.NotShipped,
            buyerRated: false,
            sellerRated: false,
            marketplaceRatedByBuyer: false,
            marketplaceRatedBySeller: false,

            phase: 1,
            finalized: false
        });

        allTransactions.push(transaction);
        
        // Delete the offer associated with the offerID
        allOffers[offerID].valid = false;

        // Emit the TransactionInitiated event
        emit TransactionInitiated(transaction.transactionID, buyer, seller, msg.sender);
    }


    // Phase 2: Marketplace confirms shipping (seller needs to send shippingID to marketplace in real world scenario)
    function confirmShipping(uint256 transactionId, uint256 phase2Duration)
        public
        inState(transactionId, 1)
        withinTime(allTransactions[transactionId].phase1EndTime)
    {
        require(msg.sender == allTransactions[transactionId].marketplace, "Only marketplace can confirm shipping initiation");
        allTransactions[transactionId].phase = 2;
        allTransactions[transactionId].phase2EndTime = block.timestamp + phase2Duration;
        allTransactions[transactionId].deliveryState == DeliveryState.NotShippedMissingData;
    }

    //Function to update the delivery state and initiate the next phase
    function updateDeliveryState(uint256 transactionId, DeliveryState deliveryState)
        public
        inState(transactionId, 2)
        withinTime(allTransactions[transactionId].phase2EndTime)

    {
        require(msg.sender == allTransactions[transactionId].marketplace, "Only marketplace can update delivery state");
        allTransactions[transactionId].deliveryState = deliveryState;

        if (deliveryState == DeliveryState.NotShippedDeliveryProblem) {
            cancelTransaction(transactionId);
        }else{
            allTransactions[transactionId].deliveryState == DeliveryState.Shipped;
        }

        allTransactions[transactionId].phase = 3;

    }

    // Phase 3: Rate the transaction
    function rateTransaction(uint256 transactionId) 
        public 
        inState(transactionId, 3) 
        withinTime(allTransactions[transactionId].phase3EndTime) 
    {
        require(msg.sender == allTransactions[transactionId].buyer || msg.sender == allTransactions[transactionId].seller, "Only buyer or seller can rate transaction");

        allTransactions[transactionId].finalized = true;

        emit TransactionFinalized(transactionId, true);
    }

    //Finalize Transaction
    function finalizeTransaction() public {
        for(uint i = 0; i < allTransactions.length; i++){
            if(allTransactions[i].phase == 3 && allTransactions[i].buyerRated && allTransactions[i].sellerRated){
                allTransactions[i].finalized = true;
            }   
        }
    }

/*     // Function to get the current phase/state of a transaction
    function getTransactionPhase(uint256 transactionId) public view returns (uint256) {
        require(allTransactions[transactionId].buyer != address(0), "Transaction does not exist");
        return allTransactions[transactionId].phase;
    }
 */
    function getAllTransactions() public view returns (Transaction[] memory) {
        uint256 count = 0;

        // First, count the number of non-finalized transactions
        for (uint256 i = 0; i < allTransactions.length; i++) {
            if (!allTransactions[i].finalized) {
                count++;
            }
        }

        // Create a new array with the correct size
        Transaction[] memory filteredTransactions = new Transaction[](count);
        uint256 index = 0;

        // Populate the new array with non-finalized transactions
        for (uint256 i = 0; i < allTransactions.length; i++) {
            if (!allTransactions[i].finalized) {
                filteredTransactions[index] = allTransactions[i];
                index++;
            }
        }

        return filteredTransactions;
    }



    // Function to rate another participant
    function rateParticipant(uint256 transactionId, uint8 ratingParticipant, uint8 ratingMarketplace) public {
        require(ratingParticipant >= 1 && ratingParticipant <= 10, "Rating must be between 1 and 10");
        require(ratingMarketplace >= 1 && ratingMarketplace <= 10, "Rating must be between 1 and 10");
        Transaction storage txn = allTransactions[transactionId];
        require(txn.phase == 3, "Transaction not ratable yet");
        require(
            msg.sender == txn.buyer || msg.sender == txn.seller,
            "Only participants can rate"
        );
        require(users[msg.sender].exists, "Participant not registered");

        if (msg.sender == txn.buyer) {
            require(!txn.buyerRated, "Buyer already rated");
            users[allTransactions[transactionId].seller].ratingSum += ratingParticipant;
            users[allTransactions[transactionId].seller].ratingCount++;

            users[txn.marketplace].ratingSum += ratingMarketplace;
            users[txn.marketplace].ratingCount++;

            txn.buyerRated = true;
            txn.marketplaceRatedByBuyer = true;


        } else if (msg.sender == txn.seller) {
            require(!txn.sellerRated, "Seller already rated");
            users[allTransactions[transactionId].buyer].ratingSum += ratingParticipant;
            users[allTransactions[transactionId].buyer].ratingCount++;      

            users[txn.marketplace].ratingSum += ratingMarketplace;
            users[txn.marketplace].ratingCount++;      

            txn.sellerRated = true;
            txn.marketplaceRatedBySeller = true;
        }

    }

    // Function to check if the current phase has expired
    function cancelTransactionsIfElapsed() public {
        for (uint i = 0; i < allTransactions.length; i++) {
            if (allTransactions[i].finalized && block.timestamp > allTransactions[i].phaseEndTime) {
                cancelTransaction(allTransactions[i].transactionID); // Automatically cancels transactions which expired a phase
            }
        }
    }

    // Cancel a transaction
    function cancelTransaction(uint256 transactionId) public {
        require(!allTransactions[transactionId].finalized, "Transaction already canceled or finalized");

         // 1: Initiated, 2: Shipping, 3: Confirming, 4: Finalizing
        if(allTransactions[transactionId].phase == 1) { 
        

        }else if(allTransactions[transactionId].phase == 2) { 


        }else if(allTransactions[transactionId].phase == 3) {


        }
        
        allTransactions[transactionId].finalized = true;
    }



/*     function checkUpkeep(bytes calldata) external view returns (bool upkeepNeeded, bytes memory) {
        upkeepNeeded = false;
        for (uint256 i = 0; i < allTransactions.length; i++) {
            if (allTransactions[i].finalized && block.timestamp > allTransactions[i].phase) {
                upkeepNeeded = true;
                break;
            }
        }
    }

    function performUpkeep(bytes calldata) external {
        for (uint256 i = 0; i < allTransactions.length(); i++) {
            if (allTransactions[i].active && block.timestamp > allTransactions[i].phaseEndTime) {
                cancelTransaction(i); // Automatically cancels expired transactions
            }
        }
    } */

}
 
