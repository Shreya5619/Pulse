// pulse/contracts/index.ts
import { JSONSchema } from "ajv";

//
// 1. Import schemas as `const`
//

import eventSchemaRaw from "./event.schema.json" assert { type: "json" };
import contextSnapshotSchemaRaw from "./context_snapshot.schema.json" assert { type: "json" };
import riskScoreSchemaRaw from "./risk_score.schema.json" assert { type: "json" };
import interventionSchemaRaw from "./intervention.schema.json" assert { type: "json" };
import feedbackSchemaRaw from "./feedback.schema.json" assert { type: "json" };

export const eventSchema = eventSchemaRaw as JSONSchema;
export const contextSnapshotSchema = contextSnapshotSchemaRaw as JSONSchema;
export const riskScoreSchema = riskScoreSchemaRaw as JSONSchema;
export const interventionSchema = interventionSchemaRaw as JSONSchema;
export const feedbackSchema = feedbackSchemaRaw as JSONSchema;

//
// 2. Validator registry (AJV)
//

import Ajv from "ajv/dist/2020";
import addFormats from "ajv-formats";

const ajv = new Ajv({ useDefaults: true });
addFormats(ajv);

export const validators = {
    event: ajv.compile(eventSchema),
    contextSnapshot: ajv.compile(contextSnapshotSchema),
    riskScore: ajv.compile(riskScoreSchema),
    intervention: ajv.compile(interventionSchema),
    feedback: ajv.compile(feedbackSchema),
};

//
// 3. Type guards and helpers
//

export type ValidateResult = {
    valid: boolean;
    errors?: unknown[];
};

export function validateEvent(data: unknown): ValidateResult {
    const valid = validators.event(data);
    return { valid, errors: !valid ? validators.event.errors : undefined };
}

export function validateContextSnapshot(data: unknown): ValidateResult {
    const valid = validators.contextSnapshot(data);
    return { valid, errors: !valid ? validators.contextSnapshot.errors : undefined };
}

export function validateRiskScore(data: unknown): ValidateResult {
    const valid = validators.riskScore(data);
    return { valid, errors: !valid ? validators.riskScore.errors : undefined };
}

export function validateIntervention(data: unknown): ValidateResult {
    const valid = validators.intervention(data);
    return { valid, errors: !valid ? validators.intervention.errors : undefined };
}

export function validateFeedback(data: unknown): ValidateResult {
    const valid = validators.feedback(data);
    return { valid, errors: !valid ? validators.feedback.errors : undefined };
}

//
// 4. Use in your API / agents
//
// Example in your route handler:
//
// const body = await req.json();
// const { valid, errors } = validateEvent(body);
// if (!valid) {
//   return res.status(400).json({ error: "bad event", details: errors });
// }
//

export default validators;