import { mkdirSync, writeFileSync } from "node:fs";
import { greeting } from "../src/greeting.js";

const dist = new URL("../dist/", import.meta.url);
mkdirSync(dist, { recursive: true });
writeFileSync(new URL("index.html", dist), `<!doctype html><p>${greeting()}</p>\n`);
