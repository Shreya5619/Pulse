const test = async () => {
    const messages = [
        "Why is my risk high right now?",
        "What happens if I leave 15 mins late?",
        "I prefer studying late at night",
        "Add a 30 min workout at 5 PM today"
    ];

    for (const msg of messages) {
        console.log(`\n--- Testing: "${msg}" ---`);
        try {
            const response = await fetch("http://localhost:8080/api/chat/message", {
                method: "POST",
                headers: { "Content-Type": "application/json", "X-User-Id": "user1" },
                body: JSON.stringify({ message: msg })
            });
            const data = await response.json();
            console.log("Response:", JSON.stringify(data, null, 2));
        } catch (e) {
            console.error("Error:", e.message);
        }
    }
};

test();
