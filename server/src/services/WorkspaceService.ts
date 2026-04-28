import fs from "fs";
import path from "path";

/**
 * WorkspaceService manages access to OpenClaw-style configuration files (SOUL, AGENTS, etc.)
 * providing agents with the necessary context for reasoning and safety.
 */
export class WorkspaceService {
  private openclawDir: string;

  constructor() {
    this.openclawDir = path.resolve(__dirname, "../../../data/openclaw");
  }

  getSoul(): string {
    return this.readFile("SOUL.md");
  }

  getAgents(): string {
    return this.readFile("agents.md");
  }

  getUser(): string {
    return this.readFile("user.md");
  }

  getHeartbeat(): string {
    return this.readFile("heartbeat.md");
  }

  private readFile(filename: string): string {
    const filePath = path.join(this.openclawDir, filename);
    if (!fs.existsSync(filePath)) {
      console.warn(`[WorkspaceService] File not found: ${filePath}`);
      return "";
    }
    return fs.readFileSync(filePath, "utf8");
  }

  getConfig() {
    return {
      soul: this.getSoul(),
      agents: this.getAgents(),
      user: this.getUser(),
      heartbeat: this.getHeartbeat()
    };
  }
}

export const workspaceService = new WorkspaceService();
