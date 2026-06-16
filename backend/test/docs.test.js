const assert = require("node:assert/strict");
const { describe, it } = require("node:test");
const openApiSpec = require("../docs/openapi");

describe("API documentation", () => {
  it("defines the LifeOS OpenAPI specification", () => {
    assert.equal(openApiSpec.openapi, "3.0.3");
    assert.equal(openApiSpec.info.title, "LifeOS API");
    assert.ok(openApiSpec.components.securitySchemes.bearerAuth);
  });

  it("documents authenticated budget group and shared expense endpoints", () => {
    const budgetGroups = openApiSpec.paths["/budget/groups"];
    const sharedExpenses =
      openApiSpec.paths["/budget/groups/{groupId}/expenses"];

    assert.ok(budgetGroups.get);
    assert.deepEqual(budgetGroups.get.security, [{ bearerAuth: [] }]);
    assert.ok(sharedExpenses.post);
    assert.deepEqual(sharedExpenses.post.security, [{ bearerAuth: [] }]);
    assert.deepEqual(
      sharedExpenses.post.requestBody.content["application/json"].schema
        .required,
      ["title", "amount", "expense_date", "participant_ids"]
    );
  });
});
