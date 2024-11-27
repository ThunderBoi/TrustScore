import React, { useState } from "react";
const ethers = require("ethers");

const App: React.FC = () => {
    const [buyer, setBuyer] = useState<string>("");
    const [seller, setSeller] = useState<string>("");
    const [marketplace, setMarketplace] = useState<string>("");
    const [transactionId, setTransactionId] = useState<number | null>(null);
    const [users, setUsers] = useState<string[]>([]);

    // Register a new user
    const registerUser = async (address: string) => {
        try {
            const tx = await ethers.contract.connect(ethers.provider.getSigner(address)).registerUser();
            await tx.wait(); // Wait for the transaction to be mined
            alert(`User registered successfully: ${address}`);
        } catch (error) {
            console.error("Error registering user:", error);
            alert("Failed to register user.");
        }
    };

    // Initiate a transaction
    const initiateTransaction = async () => {
        if (!buyer || !seller || !marketplace) {
            alert("Please provide buyer, seller, and marketplace addresses.");
            return;
        }
        try {
            const tx = await ethers.contract
                .connect(ethers.provider.getSigner(marketplace))
                .initiateTransaction(buyer, seller);
            await tx.wait();
            const newTransactionId = await ethers.contract.transactionCount();
            setTransactionId(newTransactionId.toNumber());
            alert(`Transaction initiated successfully with ID: ${newTransactionId}`);
        } catch (error) {
            console.error("Error initiating transaction:", error);
            alert("Failed to initiate transaction.");
        }
    };

    // Fetch all registered users
    const fetchUsers = async () => {
        try {
            const allUsers = await ethers.contract.getAllUsers();
            setUsers(allUsers);
        } catch (error) {
            console.error("Error fetching users:", error);
            alert("Failed to fetch users.");
        }
    };

    return (
        <div style={{ padding: "20px" }}>
            <h1>Reputation State Machine UI</h1>

            <div>
                <h2>Set Addresses</h2>
                <input
                    type="text"
                    placeholder="Buyer Address"
                    value={buyer}
                    onChange={(e) => setBuyer(e.target.value)}
                />
                <input
                    type="text"
                    placeholder="Seller Address"
                    value={seller}
                    onChange={(e) => setSeller(e.target.value)}
                />
                <input
                    type="text"
                    placeholder="Marketplace Address"
                    value={marketplace}
                    onChange={(e) => setMarketplace(e.target.value)}
                />
            </div>

            <div>
                <h2>Register User</h2>
                <button onClick={() => registerUser(buyer)}>Register Buyer</button>
                <button onClick={() => registerUser(seller)}>Register Seller</button>
                <button onClick={() => registerUser(marketplace)}>Register Marketplace</button>
            </div>

            <div>
                <h2>Initiate Transaction</h2>
                <button onClick={initiateTransaction}>Initiate</button>
            </div>

            <div>
                <h2>Get Registered Users</h2>
                <button onClick={fetchUsers}>Fetch Users</button>
                <ul>
                    {users.map((user, index) => (
                        <li key={index}>{user}</li>
                    ))}
                </ul>
            </div>

            <div>
                <h2>Transaction Status</h2>
                {transactionId !== null ? (
                    <p>Last transaction ID: {transactionId}</p>
                ) : (
                    <p>No transaction initiated yet.</p>
                )}
            </div>
        </div>
    );
};

export default App;
