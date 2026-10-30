import assert from "node:assert/strict";
import { test } from "node:test";
import { greeting } from "./greeting.js";

test("greeting uses the generated name", () => {
  assert.equal(greeting(), "hello from web-fixture");
});
