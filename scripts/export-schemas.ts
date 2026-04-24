import { zodToJsonSchema } from "zod-to-json-schema";
import { ContextSnapshotSchema } from "../shared/context_snapshot";
import * as fs from "fs";
import * as path from "path";

/**
 * This script exports the Zod schema to a JSON schema file.
 * This is useful for cross-platform alignment (e.g., Android dev).
 * 
 * NOTE: If zod-to-json-schema fails to produce a full schema in some environments,
 * the JSON schema may need to be updated manually in contracts/context_snapshot.schema.json.
 */

try {
  const schema = zodToJsonSchema(ContextSnapshotSchema, "ContextSnapshot");
  const outputPath = path.join(__dirname, "../contracts/context_snapshot.schema.json");

  // Only write if it produced a meaningful schema
  if (schema && (schema as any).definitions && (schema as any).definitions.ContextSnapshot) {
    fs.writeFileSync(outputPath, JSON.stringify(schema, null, 2));
    console.log(`✅ Exported ContextSnapshot schema to ${outputPath}`);
  } else {
    console.warn("⚠️ zod-to-json-schema produced an empty schema. Keeping manual version.");
  }
} catch (error) {
  console.error("❌ Failed to export schema:", error);
}
