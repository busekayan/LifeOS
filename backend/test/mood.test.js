const assert = require("node:assert/strict");
const { beforeEach, describe, it } = require("node:test");

const mockPool = {
  queries: [],
  queue: [],
  query(sql, params) {
    this.queries.push({ sql, params });

    if (this.queue.length === 0) {
      throw new Error(`Unexpected query: ${sql}`);
    }

    const nextResult = this.queue.shift();

    if (typeof nextResult === "function") {
      return Promise.resolve(nextResult(sql, params));
    }

    return Promise.resolve(nextResult);
  },
};

require.cache[require.resolve("../config/db")] = { exports: mockPool };

const { getMonthlyMoods } = require("../controllers/moodController");

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

const authenticatedRequest = ({ query = {} } = {}) => ({
  user: { userId: 7 },
  query,
});

describe("mood APIs", () => {
  beforeEach(() => {
    mockPool.queries = [];
    mockPool.queue = [];
  });

  it("lists monthly moods for the authenticated user", async () => {
    mockPool.queue.push({
      rows: [
        { mood: "mutlu", log_date: "2026-06-03" },
        { mood: "sakin", log_date: new Date("2026-06-12T00:00:00.000Z") },
      ],
    });

    const req = authenticatedRequest({ query: { year: "2026", month: "6" } });
    const res = createResponse();

    await getMonthlyMoods(req, res);

    assert.equal(res.statusCode, 200);
    assert.match(mockPool.queries[0].sql, /FROM mood_logs/i);
    assert.deepEqual(mockPool.queries[0].params, [
      7,
      "2026-06-01",
      "2026-07-01",
    ]);
    assert.deepEqual(res.body.moods, [
      { mood: "mutlu", log_date: "2026-06-03" },
      { mood: "sakin", log_date: "2026-06-12" },
    ]);
  });

  it("handles months with no mood data", async () => {
    mockPool.queue.push({ rows: [] });

    const req = authenticatedRequest({ query: { year: "2026", month: "7" } });
    const res = createResponse();

    await getMonthlyMoods(req, res);

    assert.equal(res.statusCode, 200);
    assert.deepEqual(res.body.moods, []);
  });

  it("rejects invalid month filters", async () => {
    const req = authenticatedRequest({ query: { year: "2026", month: "13" } });
    const res = createResponse();

    await getMonthlyMoods(req, res);

    assert.equal(res.statusCode, 400);
    assert.equal(res.body.message, "invalid year or month");
    assert.equal(mockPool.queries.length, 0);
  });
});
