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

    if (/CREATE TABLE IF NOT EXISTS friendships/i.test(sql)) {
      return Promise.resolve({ rows: [] });
    }

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
  getAcceptedFriends,
  getPersonalTransactions,
  createPersonalTransaction,
  getBudgetGroups,
  createBudgetGroup,
} = require("../controllers/budgetController");
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

const authenticatedRequest = ({ body = {}, query = {} } = {}) => ({
  user: { userId: 7 },
  body,
  query,
});

describe("budget group APIs", () => {
  beforeEach(() => {
    mockPool.queries = [];
    mockPool.queue = [];
    mockPool.connectCalls = 0;

    mockClient.queries = [];
    mockClient.queue = [];
    mockClient.released = false;
  });

  it("lists accepted friends for the authenticated user", async () => {
    mockPool.queue.push({
      rows: [
        {
          id: 12,
          first_name: "Ece",
          last_name: "Yilmaz",
          email: "ece@example.com",
        },
      ],
    });

    const req = authenticatedRequest();
    const res = createResponse();

    await getAcceptedFriends(req, res);

    assert.equal(res.statusCode, 200);
    assert.match(mockPool.queries[1].sql, /FROM friendships/i);
    assert.deepEqual(mockPool.queries[1].params, [7]);
    assert.equal(res.body.friends.length, 1);
    assert.equal(res.body.friends[0].email, "ece@example.com");
  });

  it("lists budget groups for the authenticated user", async () => {
    mockPool.queue.push({
      rows: [
        {
          id: 3,
          name: "Ev Arkadaşları",
          created_by: 7,
          members: [
            { id: 7, first_name: "Buse", last_name: "Kayan" },
            { id: 12, first_name: "Ece", last_name: "Yilmaz" },
          ],
        },
      ],
    });

    const req = authenticatedRequest();
    const res = createResponse();

    await getBudgetGroups(req, res);

    assert.equal(res.statusCode, 200);
    const groupsQuery = mockPool.queries.find((query) =>
      /budget_group_members/i.test(query.sql)
    );
    assert.ok(groupsQuery);
    assert.deepEqual(groupsQuery.params, [7]);
    assert.equal(res.body.groups[0].name, "Ev Arkadaşları");
    assert.equal(res.body.groups[0].members.length, 2);
  });

  it("lists monthly personal transactions with summary", async () => {
    mockPool.queue.push({
      rows: [{ income_total: 5000, expense_total: 1200 }],
    });
    mockPool.queue.push({
      rows: [
        {
          id: 4,
          type: "expense",
          title: "Market",
          amount: 450,
          transaction_date: "2026-06-12",
          note: "Weekly groceries",
        },
      ],
    });

    const req = authenticatedRequest({ query: { month: "2026-06" } });
    const res = createResponse();

    await getPersonalTransactions(req, res);

    assert.equal(res.statusCode, 200);
    assert.deepEqual(res.body.summary, {
      income_total: 5000,
      expense_total: 1200,
      shared_expense_total: 0,
      remaining_balance: 3800,
    });
    assert.equal(res.body.transactions.length, 1);
    assert.equal(res.body.transactions[0].title, "Market");
    assert.deepEqual(mockPool.queries.at(-2).params, [
      7,
      "2026-06-01",
      "2026-07-01",
    ]);
  });

  it("creates a personal income transaction", async () => {
    mockPool.queue.push({
      rows: [
        {
          id: 8,
          type: "income",
          title: "Salary",
          amount: 5000,
          transaction_date: "2026-06-01",
          note: null,
        },
      ],
    });

    const req = authenticatedRequest({
      body: {
        type: "income",
        title: "Salary",
        amount: 5000,
        transaction_date: "2026-06-01",
      },
    });
    const res = createResponse();

    await createPersonalTransaction(req, res);

    assert.equal(res.statusCode, 201);
    assert.equal(res.body.message, "Budget transaction created successfully");
    assert.equal(res.body.transaction.type, "income");
    assert.match(mockPool.queries.at(-1).sql, /INSERT INTO budget_transactions/i);
    assert.deepEqual(mockPool.queries.at(-1).params, [
      7,
      "income",
      "Salary",
      5000,
      "2026-06-01",
      null,
    ]);
  });

  it("creates a personal expense transaction", async () => {
    mockPool.queue.push({
      rows: [
        {
          id: 9,
          type: "expense",
          title: "Coffee",
          amount: 95,
          transaction_date: "2026-06-13",
          note: "Latte",
        },
      ],
    });

    const req = authenticatedRequest({
      body: {
        type: "expense",
        title: "Coffee",
        amount: 95,
        transaction_date: "2026-06-13",
        note: "Latte",
      },
    });
    const res = createResponse();

    await createPersonalTransaction(req, res);

    assert.equal(res.statusCode, 201);
    assert.equal(res.body.transaction.type, "expense");
    assert.equal(res.body.transaction.title, "Coffee");
  });

  it("rejects invalid personal transaction input", async () => {
    const req = authenticatedRequest({
      body: {
        type: "expense",
        title: "",
        amount: -1,
        transaction_date: "2026-06-13",
      },
    });
    const res = createResponse();

    await createPersonalTransaction(req, res);

    assert.equal(res.statusCode, 400);
    assert.equal(res.body.message, "Invalid transaction details");
  });

  it("creates a shared budget group with accepted friends", async () => {
    mockClient.queue.push({ rows: [] }); // BEGIN
    mockClient.queue.push({ rows: [{ friend_id: 12 }, { friend_id: 13 }] });
    mockClient.queue.push({
      rows: [
        {
          id: 3,
          name: "Ev Arkadaşları",
          created_by: 7,
          created_at: "2026-06-13",
        },
      ],
    });
    mockClient.queue.push({ rows: [] }); // creator member
    mockClient.queue.push({ rows: [] }); // friend member
    mockClient.queue.push({ rows: [] }); // friend member
    mockClient.queue.push({
      rows: [
        { id: 7, first_name: "Buse", last_name: "Kayan" },
        { id: 12, first_name: "Ece", last_name: "Yilmaz" },
        { id: 13, first_name: "Mert", last_name: "Demir" },
      ],
    });
    mockClient.queue.push({ rows: [] }); // COMMIT

    const req = authenticatedRequest({
      body: {
        name: "Ev Arkadaşları",
        memberIds: [12, 13],
      },
    });
    const res = createResponse();

    await createBudgetGroup(req, res);

    assert.equal(res.statusCode, 201);
    assert.equal(res.body.message, "Budget group created successfully");
    assert.equal(res.body.group.name, "Ev Arkadaşları");
    assert.equal(res.body.group.members.length, 3);
    assert.match(mockClient.queries[1].sql, /FROM friendships/i);
    assert.deepEqual(mockClient.queries[1].params, [7, [12, 13]]);
    assert.match(mockClient.queries[2].sql, /INSERT INTO budget_groups/i);
    assert.deepEqual(mockClient.queries[2].params, ["Ev Arkadaşları", 7]);
    assert.deepEqual(mockClient.queries[3].params, [3, 7]);
    assert.deepEqual(mockClient.queries[4].params, [3, 12]);
    assert.deepEqual(mockClient.queries[5].params, [3, 13]);
    assert.equal(mockClient.released, true);
  });

  it("rejects adding users who are not accepted friends", async () => {
    mockClient.queue.push({ rows: [] }); // BEGIN
    mockClient.queue.push({ rows: [{ friend_id: 12 }] });
    mockClient.queue.push({ rows: [] }); // ROLLBACK

    const req = authenticatedRequest({
      body: {
        name: "Trip",
        memberIds: [12, 99],
      },
    });
    const res = createResponse();

    await createBudgetGroup(req, res);

    assert.equal(res.statusCode, 403);
    assert.equal(res.body.message, "Only accepted friends can be added to a group");
    assert.match(mockClient.queries[2].sql, /ROLLBACK/i);
    assert.equal(mockClient.released, true);
  });

  it("requires a valid JWT token for budget endpoints", () => {
    const missingTokenReq = { headers: {} };
    const missingTokenRes = createResponse();

    verifyToken(missingTokenReq, missingTokenRes, () => {});

    assert.equal(missingTokenRes.statusCode, 401);
    assert.equal(
      missingTokenRes.body.message,
      "Access denied. No token provided."
    );
  });
});
