const assert = require("node:assert/strict");
const { beforeEach, describe, it } = require("node:test");

const mockClient = {
  queries: [],
  queue: [],
  released: false,
  query(sql, params) {
    this.queries.push({ sql, params });

    if (this.queue.length === 0) {
      throw new Error(`Unexpected client query: ${sql}`);
    }

    const nextResult = this.queue.shift();

    if (typeof nextResult === "function") {
      return Promise.resolve(nextResult(sql, params));
    }

    return Promise.resolve(nextResult);
  },
  release() {
    this.released = true;
  },
};

const mockPool = {
  queries: [],
  queue: [],
  connectCalls: 0,
  connect() {
    this.connectCalls += 1;
    return Promise.resolve(mockClient);
  },
  query(sql, params) {
    this.queries.push({ sql, params });

    if (this.queue.length === 0) {
      throw new Error(`Unexpected pool query: ${sql}`);
    }

    const nextResult = this.queue.shift();

    if (typeof nextResult === "function") {
      return Promise.resolve(nextResult(sql, params));
    }

    return Promise.resolve(nextResult);
  },
};

require.cache[require.resolve("../config/db")] = { exports: mockPool };

const {
  getHabitTemplates,
  addHabitTemplate,
  deleteHabitTemplateGroup,
} = require("../controllers/habitTemplateController");
const verifyToken = require("../middleware/verifyToken");

const createResponse = () => {
  const res = {
    statusCode: 200,
    body: undefined,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(payload) {
      this.body = payload;
      return this;
    },
  };

  return res;
};

const authenticatedRequest = ({ params = {} } = {}) => ({
  user: { userId: 7 },
  params,
});

describe("habit template APIs", () => {
  beforeEach(() => {
    mockPool.queries = [];
    mockPool.queue = [];
    mockPool.connectCalls = 0;

    mockClient.queries = [];
    mockClient.queue = [];
    mockClient.released = false;
  });

  it("fetches habit templates and template categories", async () => {
    mockPool.queue.push({ rows: [] }); // schema setup
    mockPool.queue.push({
      rows: [
        {
          id: 1,
          title: "Sabah Savaşçısı",
          description: "Morning routine",
          image_url: "https://example.com/morning.jpg",
          is_featured: true,
          display_order: 1,
          category: "Fitness",
          category_emoji: "🏋️",
          is_added: false,
          habit_count: 2,
          habits: [
            {
              id: 10,
              name: "7 AM Uyanış",
              description: "Wake up",
              period: "morning",
              frequency_type: "weekly",
              days: [1, 2, 3, 4, 5],
              target_value: null,
              goal_unit: null,
              display_order: 1,
            },
          ],
        },
        {
          id: 2,
          title: "Huzurlu Akşamlar",
          description: "Evening routine",
          image_url: "https://example.com/evening.jpg",
          is_featured: false,
          display_order: 1,
          category: "Wellness",
          category_emoji: "🧘",
          is_added: true,
          habit_count: 1,
          habits: [],
        },
      ],
    });

    const req = authenticatedRequest();
    const res = createResponse();

    await getHabitTemplates(req, res);

    assert.equal(res.statusCode, 200);
    assert.deepEqual(mockPool.queries[1].params, [7]);
    assert.deepEqual(res.body.categories, ["Fitness", "Wellness"]);
    assert.equal(res.body.templates.length, 2);
    assert.equal(res.body.templates[0].title, "Sabah Savaşçısı");
    assert.equal(res.body.templates[0].habit_count, 2);
    assert.equal(res.body.templates[1].is_added, true);
  });

  it("adds a template to the user's habits", async () => {
    mockClient.queue.push({ rows: [] }); // BEGIN
    mockClient.queue.push({ rows: [{ id: 1, title: "Sabah Savaşçısı" }] });
    mockClient.queue.push({ rows: [{ id: 55 }] });
    mockClient.queue.push({
      rows: [
        {
          name: "7 AM Uyanış",
          description: "Wake up",
          period: "morning",
          frequency_type: "weekly",
          days: [1, 2],
          target_value: null,
          goal_unit: null,
        },
        {
          name: "10 dk Esneme",
          description: "Stretch",
          period: "morning",
          frequency_type: "weekly",
          days: [1],
          target_value: 10,
          goal_unit: "minute",
        },
      ],
    });
    mockClient.queue.push({ rows: [{ id: 101 }] });
    mockClient.queue.push({ rows: [] });
    mockClient.queue.push({ rows: [] });
    mockClient.queue.push({ rows: [{ id: 102 }] });
    mockClient.queue.push({ rows: [] });
    mockClient.queue.push({ rows: [] }); // COMMIT

    const req = authenticatedRequest({ params: { id: "1" } });
    const res = createResponse();

    await addHabitTemplate(req, res);

    assert.equal(res.statusCode, 201);
    assert.equal(res.body.message, "Template added successfully");
    assert.equal(res.body.addedCount, 2);
    assert.deepEqual(res.body.habitIds, [101, 102]);
    assert.match(mockClient.queries[2].sql, /INSERT INTO user_template_additions/i);
    assert.deepEqual(mockClient.queries[2].params, [7, "1"]);
    assert.match(mockClient.queries[4].sql, /INSERT INTO habits/i);
    assert.deepEqual(mockClient.queries[4].params, [
      7,
      "7 AM Uyanış",
      "Wake up",
      "weekly",
      "morning",
      null,
      null,
      "1",
      "Sabah Savaşçısı",
    ]);
    assert.match(mockClient.queries[5].sql, /INSERT INTO habit_days/i);
    assert.deepEqual(mockClient.queries[5].params, [101, 1]);
    assert.equal(mockClient.released, true);
  });

  it("rejects adding the same template more than once", async () => {
    mockClient.queue.push({ rows: [] }); // BEGIN
    mockClient.queue.push({ rows: [{ id: 1, title: "Sabah Savaşçısı" }] });
    mockClient.queue.push({ rows: [] });
    mockClient.queue.push({ rows: [] }); // ROLLBACK

    const req = authenticatedRequest({ params: { id: "1" } });
    const res = createResponse();

    await addHabitTemplate(req, res);

    assert.equal(res.statusCode, 409);
    assert.equal(res.body.message, "Template already added");
    assert.equal(res.body.alreadyAdded, true);
    assert.equal(res.body.addedCount, 0);
    assert.match(mockClient.queries[3].sql, /ROLLBACK/i);
    assert.equal(mockClient.released, true);
  });

  it("requires a valid JWT token for template endpoints", () => {
    const missingTokenReq = { headers: {} };
    const missingTokenRes = createResponse();

    verifyToken(missingTokenReq, missingTokenRes, () => {});

    assert.equal(missingTokenRes.statusCode, 401);
    assert.equal(
      missingTokenRes.body.message,
      "Access denied. No token provided."
    );

    const invalidTokenReq = {
      headers: {
        authorization: "Bearer invalid-token",
      },
    };
    const invalidTokenRes = createResponse();

    verifyToken(invalidTokenReq, invalidTokenRes, () => {});

    assert.equal(invalidTokenRes.statusCode, 401);
    assert.equal(invalidTokenRes.body.message, "Invalid or expired token");
  });

  it("returns not found when adding an unknown template", async () => {
    mockClient.queue.push({ rows: [] }); // BEGIN
    mockClient.queue.push({ rows: [] });
    mockClient.queue.push({ rows: [] }); // ROLLBACK

    const req = authenticatedRequest({ params: { id: "999" } });
    const res = createResponse();

    await addHabitTemplate(req, res);

    assert.equal(res.statusCode, 404);
    assert.equal(res.body.message, "Habit template not found");
    assert.equal(mockClient.released, true);
  });

  it("returns an error when a template has no habits", async () => {
    mockClient.queue.push({ rows: [] }); // BEGIN
    mockClient.queue.push({ rows: [{ id: 1, title: "Empty Template" }] });
    mockClient.queue.push({ rows: [{ id: 55 }] });
    mockClient.queue.push({ rows: [] });
    mockClient.queue.push({ rows: [] }); // ROLLBACK

    const req = authenticatedRequest({ params: { id: "1" } });
    const res = createResponse();

    await addHabitTemplate(req, res);

    assert.equal(res.statusCode, 400);
    assert.equal(res.body.message, "This template has no habits");
    assert.equal(mockClient.released, true);
  });

  it("deletes a template habit group and allows it to be added again", async () => {
    mockClient.queue.push({ rows: [] }); // BEGIN
    mockClient.queue.push({ rows: [{ id: 1 }] });
    mockClient.queue.push({ rows: [{ id: 101 }, { id: 102 }] });
    mockClient.queue.push({ rows: [] });
    mockClient.queue.push({ rows: [] });
    mockClient.queue.push({ rows: [] });
    mockClient.queue.push({ rows: [] });
    mockClient.queue.push({ rows: [] }); // COMMIT

    const req = authenticatedRequest({ params: { id: "1" } });
    const res = createResponse();

    await deleteHabitTemplateGroup(req, res);

    assert.equal(res.statusCode, 200);
    assert.equal(res.body.message, "Template group deleted successfully");
    assert.equal(res.body.deletedCount, 2);
    assert.match(mockClient.queries[2].sql, /FROM habits/i);
    assert.deepEqual(mockClient.queries[2].params, [7, "1"]);
    assert.match(mockClient.queries[3].sql, /DELETE FROM habit_logs/i);
    assert.deepEqual(mockClient.queries[3].params, [7, [101, 102]]);
    assert.match(mockClient.queries[4].sql, /DELETE FROM habit_days/i);
    assert.deepEqual(mockClient.queries[4].params, [[101, 102]]);
    assert.match(mockClient.queries[5].sql, /DELETE FROM habits/i);
    assert.deepEqual(mockClient.queries[5].params, [7, "1"]);
    assert.match(mockClient.queries[6].sql, /DELETE FROM user_template_additions/i);
    assert.deepEqual(mockClient.queries[6].params, [7, "1"]);
    assert.equal(mockClient.released, true);
  });

  it("does not delete another user's template group", async () => {
    mockClient.queue.push({ rows: [] }); // BEGIN
    mockClient.queue.push({ rows: [{ id: 1 }] });
    mockClient.queue.push({ rows: [] });
    mockClient.queue.push({ rows: [] }); // ROLLBACK

    const req = authenticatedRequest({ params: { id: "1" } });
    const res = createResponse();

    await deleteHabitTemplateGroup(req, res);

    assert.equal(res.statusCode, 404);
    assert.equal(res.body.message, "Template group not found");
    assert.match(mockClient.queries[2].sql, /WHERE user_id = \$1/i);
    assert.deepEqual(mockClient.queries[2].params, [7, "1"]);
    assert.match(mockClient.queries[3].sql, /ROLLBACK/i);
    assert.equal(mockClient.released, true);
  });
});
