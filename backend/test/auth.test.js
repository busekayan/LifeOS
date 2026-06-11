const assert = require("node:assert/strict");
const { beforeEach, describe, it } = require("node:test");
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");

process.env.JWT_SECRET = "test-access-secret";
process.env.JWT_REFRESH_SECRET = "test-refresh-secret";

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

const { registerUser, loginUser } = require("../controllers/userController");
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

describe("authentication endpoints", () => {
  beforeEach(() => {
    mockPool.queries = [];
    mockPool.queue = [];
  });

  it("registers a new user", async () => {
    mockPool.queue.push({ rows: [] });
    mockPool.queue.push({ rows: [] });

    const req = {
      body: {
        firstName: "Buse",
        lastName: "Kayan",
        email: "buse@example.com",
        password: "secret123",
      },
    };
    const res = createResponse();

    await registerUser(req, res);

    assert.equal(res.statusCode, 201);
    assert.equal(res.body.message, "Kullanıcı oluşturuldu");
    assert.match(mockPool.queries[0].sql, /SELECT id FROM users/i);
    assert.match(mockPool.queries[1].sql, /INSERT INTO users/i);
    assert.equal(mockPool.queries[1].params[2], "buse@example.com");
  });

  it("rejects duplicate email registration", async () => {
    mockPool.queue.push({ rows: [{ id: 1 }] });

    const req = {
      body: {
        firstName: "Buse",
        lastName: "Kayan",
        email: "buse@example.com",
        password: "secret123",
      },
    };
    const res = createResponse();

    await registerUser(req, res);

    assert.equal(res.statusCode, 400);
    assert.equal(res.body.message, "Bu email zaten kayıtlı");
    assert.equal(mockPool.queries.length, 1);
  });

  it("logs in a user and returns JWT tokens", async () => {
    const passwordHash = await bcrypt.hash("secret123", 10);

    mockPool.queue.push({
      rows: [
        {
          id: 7,
          first_name: "Buse",
          last_name: "Kayan",
          email: "buse@example.com",
          password_hash: passwordHash,
        },
      ],
    });
    mockPool.queue.push({ rows: [] });

    const req = {
      body: {
        email: "buse@example.com",
        password: "secret123",
      },
    };
    const res = createResponse();

    await loginUser(req, res);

    assert.equal(res.statusCode, 200);
    assert.equal(res.body.message, "Giriş başarılı");
    assert.ok(res.body.accessToken);
    assert.ok(res.body.refreshToken);
    assert.equal(res.body.user.email, "buse@example.com");

    const decoded = jwt.verify(res.body.accessToken, process.env.JWT_SECRET);
    assert.equal(decoded.userId, 7);
    assert.equal(decoded.email, "buse@example.com");
  });

  it("rejects login with invalid credentials", async () => {
    const passwordHash = await bcrypt.hash("secret123", 10);

    mockPool.queue.push({
      rows: [
        {
          id: 7,
          first_name: "Buse",
          last_name: "Kayan",
          email: "buse@example.com",
          password_hash: passwordHash,
        },
      ],
    });

    const req = {
      body: {
        email: "buse@example.com",
        password: "wrong-password",
      },
    };
    const res = createResponse();

    await loginUser(req, res);

    assert.equal(res.statusCode, 400);
    assert.equal(res.body.message, "Email veya şifre hatalı");
    assert.equal(mockPool.queries.length, 1);
  });

  it("requires a valid token for protected routes", async () => {
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
});
