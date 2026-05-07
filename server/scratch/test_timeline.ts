import { dayPulseService } from "../src/services/DayPulseService";

const test = async () => {
    const userId = "user1";
    const date = new Date().toISOString().split('T')[0];
    console.log(`Testing timeline for ${userId} on ${date}`);
    try {
        const pulse = await dayPulseService.getDailyTimeline(userId, date);
        console.log("Blocks found:", pulse.blocks.length);
        pulse.blocks.forEach(b => console.log(`- ${b.title} (${b.startTime} - ${b.endTime})`));
    } catch (e) {
        console.error("Error:", e);
    }
    process.exit(0);
};

test();
