import { query } from "../src/db/db";

const check = async () => {
    const res = await query("SELECT id, payload FROM manual_events ORDER BY id DESC LIMIT 5;");
    console.log(JSON.stringify(res.rows, null, 2));
    process.exit(0);
};

check();
