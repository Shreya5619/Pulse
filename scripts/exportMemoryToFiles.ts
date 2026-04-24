import { memoryRepository } from "../server/src/db/MemoryRepository";
import * as fs from "fs";
import * as path from "path";
import yaml from "js-yaml";

async function exportMemory(userId: string) {
  console.log(`[Exporter] Exporting memory for user: ${userId}`);
  
  const state = await memoryRepository.loadAll(userId);
  const baseDir = path.join(process.cwd(), 'memory', userId);

  if (!fs.existsSync(baseDir)) {
    fs.mkdirSync(baseDir, { recursive: true });
  }

  const types = Object.keys(state) as (keyof typeof state)[];

  for (const type of types) {
    const data = state[type];
    if (data) {
      const filePath = path.join(baseDir, `${type}.yaml`);
      const yamlContent = yaml.dump(data, { indent: 2 });
      
      const header = `# Runtime store is Postgres; these files are exported for transparency / OpenClaw-style inspection.\n# Exported at: ${new Date().toISOString()}\n\n`;
      
      fs.writeFileSync(filePath, header + yamlContent);
      console.log(`[Exporter] Wrote ${filePath}`);
    }
  }
}

// Get userId from command line or default to 'user_123'
const userId = process.argv[2] || 'user_123';
exportMemory(userId).then(() => {
  console.log("[Exporter] Done.");
  process.exit(0);
}).catch(err => {
  if (err.message.includes("Database connection failed")) {
    console.error(`\n[Exporter] ERROR: ${err.message}`);
    console.error("[Exporter] Please ensure Docker Desktop is running and run 'docker-compose up -d db' to start Postgres.\n");
  } else {
    console.error("[Exporter] Failed:", err);
  }
  process.exit(1);
});
