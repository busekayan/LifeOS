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
  createHabit,
  getHabits,
  getHabitSummary,
  deleteHabit,
} = require("../controllers/habitController");
const {
  toggleHabitLog,
  updateHabitLogValue,
} = require("../controllers/habitLogController");
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

const authenticatedRequest = ({ body = {}, query = {}, params = {} } = {}) => ({
  user: { userId: 7 },
  body,
  query,
  params,
});

describe("habit APIs", () => {
  beforeEach(() => {
    mockPool.queries = [];
    mockPool.queue = [];
    mockPool.connectCalls = 0;

    mockClient.queries = [];
    mockClient.queue = [];
    mockClient.released = false;
  });

  it("creates a habit for the authenticated user", async () => {
    mockClient.queue.push({ rows: [] }); // BEGIN
    mockClient.queue.push({ rows: [{ id: 42 }] });
    mockClient.queue.push({ rows: [] });
    mockClient.queue.push({ rows: [] });
    mockClient.queue.push({ rows: [] }); // COMMIT

    const req = authenticatedRequest({
      body: {
        name: "Read",
        description: "Read before sleep",
        period: "evening",
        frequency_type: "weekly",
        days: [1, 3],
      },
    });
    const res = createResponse();

    await createHabit(req, res);

    assert.equal(res.statusCode, 201);
    assert.equal(res.body.message, "Habit created successfully");
    assert.equal(res.body.habitId, 42);
    assert.equal(mockPool.connectCalls, 1);
    assert.match(mockClient.queries[1].sql, /INSERT INTO habits/i);
    assert.deepEqual(mockClient.queries[1].params, [
      7,
      "Read",
      "Read before sleep",
      "weekly",
      "evening",
      null,
      null,
    ]);
    assert.match(mockClient.queries[2].sql, /INSERT INTO habit_days/i);
    assert.deepEqual(mockClient.queries[2].params, [42, 1]);
    assert.deepEqual(mockClient.queries[3].params, [42, 3]);
    assert.equal(mockClient.released, true);
  });

  it("rejects invalid habit creation input", async () => {
    const req = authenticatedRequest({
      body: {
        name: "Read",
        period: "night",
        frequency_type: "weekly",
        days: [1],
      },
    });
    const res = createResponse();

    await createHabit(req, res);

    assert.equal(res.statusCode, 400);
    assert.equal(res.body.message, "Invalid period value");
    assert.equal(mockClient.queries.length, 0);
    assert.equal(mockClient.released, true);
  });

  it("lists habits for the authenticated user grouped by habit days", async () => {
    mockPool.queue.push({ rows: [] }); // source columns setup
    mockPool.queue.push({
      rows: [
        {
          id: 42,
          name: "Read",
          description: "Read before sleep",
          period: "evening",
          frequency_type: "weekly",
          target_value: null,
          goal_unit: null,
          source_template_id: null,
          source_template_title: null,
          day_of_week: 1,
          current_value: 1,
          is_completed: true,
        },
        {
          id: 42,
          name: "Read",
          description: "Read before sleep",
          period: "evening",
          frequency_type: "weekly",
          target_value: null,
          goal_unit: null,
          source_template_id: null,
          source_template_title: null,
          day_of_week: 3,
          current_value: 1,
          is_completed: true,
        },
      ],
    });

    const req = authenticatedRequest({ query: { date: "2026-06-11" } });
    const res = createResponse();

    await getHabits(req, res);

    assert.equal(res.statusCode, 200);
    assert.match(mockPool.queries[0].sql, /ALTER TABLE habits/i);
    assert.deepEqual(mockPool.queries[1].params, [7, "2026-06-11"]);
    assert.deepEqual(res.body.habits, [
      {
        id: 42,
        name: "Read",
        description: "Read before sleep",
        period: "evening",
        frequency_type: "weekly",
        target_value: null,
        goal_type: null,
        source_template_id: null,
        source_template_title: null,
        current_value: 1,
        is_completed: true,
        days: [1, 3],
      },
    ]);
  });

  it("requires date query parameter when listing habits", async () => {
    const req = authenticatedRequest();
    const res = createResponse();

    await getHabits(req, res);

    assert.equal(res.statusCode, 400);
    assert.equal(res.body.message, "date query parameter is required");
    assert.equal(mockPool.queries.length, 0);
  });

  it("returns habit completion summary for recent activity", async () => {
    mockPool.queue.push({
      rows: [
        {
          log_date: "2026-06-15",
          planned_count: 3,
          completed_count: 2,
          missed_count: 1,
        },
        {
          log_date: new Date("2026-06-16T00:00:00.000Z"),
          planned_count: 2,
          completed_count: 1,
          missed_count: 1,
        },
      ],
    });

    const req = authenticatedRequest({
      query: { days: "7", end_date: "2026-06-16" },
    });
    const res = createResponse();

    await getHabitSummary(req, res);

    assert.equal(res.statusCode, 200);
    assert.match(mockPool.queries[0].sql, /WITH date_range AS/i);
    assert.deepEqual(mockPool.queries[0].params, [7, "2026-06-16", 7]);
    assert.deepEqual(res.body.summary, {
      totalPlanned: 5,
      completed: 3,
      missed: 2,
      completionRate: 60,
      days: [
        { date: "2026-06-15", planned: 3, completed: 2, missed: 1 },
        { date: "2026-06-16", planned: 2, completed: 1, missed: 1 },
      ],
    });
  });

  it("rejects invalid habit summary filters", async () => {
    const req = authenticatedRequest({
      query: { days: "120", end_date: "2026-06-16" },
    });
    const res = createResponse();

    await getHabitSummary(req, res);

    assert.equal(res.statusCode, 400);
    assert.equal(res.body.message, "days must be an integer between 1 and 90");
    assert.equal(mockPool.queries.length, 0);
  });

  it("requires a valid JWT token for habit endpoints", () => {
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

  it("deletes a habit and related records for the authenticated user", async () => {
    mockClient.queue.push({ rows: [] }); // BEGIN
    mockClient.queue.push({ rows: [{ id: 42 }] });
    mockClient.queue.push({ rows: [] });
    mockClient.queue.push({ rows: [] });
    mockClient.queue.push({ rows: [] });
    mockClient.queue.push({ rows: [] }); // COMMIT

    const req = authenticatedRequest({ params: { id: "42" } });
    const res = createResponse();

    await deleteHabit(req, res);

    assert.equal(res.statusCode, 200);
    assert.equal(res.body.message, "Habit deleted successfully");
    assert.match(mockClient.queries[1].sql, /SELECT id\s+FROM habits/i);
    assert.deepEqual(mockClient.queries[1].params, [42, 7]);
    assert.match(mockClient.queries[2].sql, /DELETE FROM habit_logs/i);
    assert.deepEqual(mockClient.queries[2].params, [42, 7]);
    assert.match(mockClient.queries[3].sql, /DELETE FROM habit_days/i);
    assert.deepEqual(mockClient.queries[3].params, [42]);
    assert.match(mockClient.queries[4].sql, /DELETE FROM habits/i);
    assert.deepEqual(mockClient.queries[4].params, [42, 7]);
    assert.equal(mockClient.released, true);
  });

  it("does not delete another user's habit", async () => {
    mockClient.queue.push({ rows: [] }); // BEGIN
    mockClient.queue.push({ rows: [] });
    mockClient.queue.push({ rows: [] }); // ROLLBACK

    const req = authenticatedRequest({ params: { id: "42" } });
    const res = createResponse();

    await deleteHabit(req, res);

    assert.equal(res.statusCode, 404);
    assert.equal(res.body.message, "Habit not found");
    assert.equal(mockClient.queries.length, 3);
    assert.match(mockClient.queries[2].sql, /ROLLBACK/i);
    assert.equal(mockClient.released, true);
  });

  it("rejects invalid habit id when deleting", async () => {
    const req = authenticatedRequest({ params: { id: "abc" } });
    const res = createResponse();

    await deleteHabit(req, res);

    assert.equal(res.statusCode, 400);
    assert.equal(res.body.message, "Invalid habit id");
    assert.equal(mockPool.connectCalls, 0);
  });

  it("toggles a checkbox habit as completed", async () => {
    mockPool.queue.push({ rows: [{ target_value: null }] });
    mockPool.queue.push({ rows: [] });
    mockPool.queue.push({ rows: [] });

    const req = authenticatedRequest({
      body: {
        habit_id: 42,
        log_date: "2026-06-11",
      },
    });
    const res = createResponse();

    await toggleHabitLog(req, res);

    assert.equal(res.statusCode, 201);
    assert.equal(res.body.completed, true);
    assert.equal(res.body.message, "Habit log created");
    assert.match(mockPool.queries[2].sql, /INSERT INTO habit_logs/i);
    assert.deepEqual(mockPool.queries[2].params, [42, 7, "2026-06-11", 1]);
  });

  it("toggles a completed checkbox habit back to incomplete", async () => {
    mockPool.queue.push({ rows: [{ target_value: null }] });
    mockPool.queue.push({ rows: [{ id: 100 }] });
    mockPool.queue.push({ rows: [] });

    const req = authenticatedRequest({
      body: {
        habit_id: 42,
        log_date: "2026-06-11",
      },
    });
    const res = createResponse();

    await toggleHabitLog(req, res);

    assert.equal(res.statusCode, 200);
    assert.equal(res.body.completed, false);
    assert.equal(res.body.message, "Habit log removed");
    assert.match(mockPool.queries[2].sql, /DELETE FROM habit_logs/i);
  });

  it("updates goal-based habit progress", async () => {
    mockPool.queue.push({ rows: [{ target_value: 30 }] });
    mockPool.queue.push({ rows: [] });

    const req = authenticatedRequest({
      body: {
        habit_id: 42,
        log_date: "2026-06-11",
        value: 35,
      },
    });
    const res = createResponse();

    await updateHabitLogValue(req, res);

    assert.equal(res.statusCode, 200);
    assert.equal(res.body.completed, true);
    assert.equal(res.body.current_value, 35);
    assert.equal(res.body.target_value, 30);
    assert.equal(res.body.message, "Goal reached!");
    assert.match(mockPool.queries[1].sql, /INSERT INTO habit_logs/i);
    assert.deepEqual(mockPool.queries[1].params, [42, 7, "2026-06-11", 35]);
  });

  it("returns not found when toggling another user's habit", async () => {
    mockPool.queue.push({ rows: [] });

    const req = authenticatedRequest({
      body: {
        habit_id: 999,
        log_date: "2026-06-11",
      },
    });
    const res = createResponse();

    await toggleHabitLog(req, res);

    assert.equal(res.statusCode, 404);
    assert.equal(res.body.message, "Habit not found");
  });
});
