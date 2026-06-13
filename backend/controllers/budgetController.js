const pool = require("../config/db");

let budgetSchemaReadyPromise;

const ensureBudgetSchema = () => {
  if (!budgetSchemaReadyPromise) {
    budgetSchemaReadyPromise = pool.query(`
      CREATE TABLE IF NOT EXISTS friendships (
        id SERIAL PRIMARY KEY,
        requester_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        addressee_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        status VARCHAR(20) NOT NULL DEFAULT 'pending',
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        CHECK (requester_id <> addressee_id),
        CHECK (status IN ('pending', 'accepted', 'rejected'))
      );

      CREATE UNIQUE INDEX IF NOT EXISTS uq_friendships_pair
      ON friendships (
        LEAST(requester_id, addressee_id),
        GREATEST(requester_id, addressee_id)
      );

      CREATE TABLE IF NOT EXISTS budget_groups (
        id SERIAL PRIMARY KEY,
        name VARCHAR(120) NOT NULL,
        created_by INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
      );

      CREATE TABLE IF NOT EXISTS budget_group_members (
        id SERIAL PRIMARY KEY,
        group_id INTEGER NOT NULL REFERENCES budget_groups(id) ON DELETE CASCADE,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE (group_id, user_id)
      );

      CREATE TABLE IF NOT EXISTS budget_transactions (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        type VARCHAR(20) NOT NULL,
        title VARCHAR(160) NOT NULL,
        category VARCHAR(80) NOT NULL DEFAULT 'General',
        amount NUMERIC(12, 2) NOT NULL,
        transaction_date DATE NOT NULL,
        note TEXT,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        CHECK (type IN ('income', 'expense')),
        CHECK (amount > 0)
      );

      ALTER TABLE budget_transactions
      ALTER COLUMN category SET DEFAULT 'General';
    `);
  }

  return budgetSchemaReadyPromise;
};

const getAcceptedFriends = async (req, res) => {
  try {
    await ensureBudgetSchema();

    const userId = req.user.userId;

    const result = await pool.query(
      `
      SELECT
        u.id,
        u.first_name,
        u.last_name,
        u.email
      FROM friendships f
      JOIN users u
        ON u.id = CASE
          WHEN f.requester_id = $1 THEN f.addressee_id
          ELSE f.requester_id
        END
      WHERE (f.requester_id = $1 OR f.addressee_id = $1)
        AND f.status = 'accepted'
      ORDER BY u.first_name ASC, u.last_name ASC
      `,
      [userId]
    );

    return res.status(200).json({
      friends: result.rows,
    });
  } catch (err) {
    console.error("GET ACCEPTED FRIENDS ERROR:", err);

    return res.status(500).json({
      message: "Friends could not be loaded",
    });
  }
};

const getBudgetGroups = async (req, res) => {
  try {
    await ensureBudgetSchema();

    const userId = req.user.userId;

    const result = await pool.query(
      `
      SELECT
        bg.id,
        bg.name,
        bg.created_by,
        bg.created_at,
        COALESCE(
          json_agg(
            json_build_object(
              'id', u.id,
              'first_name', u.first_name,
              'last_name', u.last_name,
              'email', u.email
            )
            ORDER BY
              CASE WHEN u.id = bg.created_by THEN 0 ELSE 1 END,
              u.first_name ASC,
              u.last_name ASC
          ) FILTER (WHERE u.id IS NOT NULL),
          '[]'
        ) AS members
      FROM budget_groups bg
      JOIN budget_group_members current_member
        ON current_member.group_id = bg.id
        AND current_member.user_id = $1
      JOIN budget_group_members bgm
        ON bgm.group_id = bg.id
      JOIN users u
        ON u.id = bgm.user_id
      GROUP BY bg.id
      ORDER BY bg.created_at DESC
      `,
      [userId]
    );

    return res.status(200).json({
      groups: result.rows,
    });
  } catch (err) {
    console.error("GET BUDGET GROUPS ERROR:", err);

    return res.status(500).json({
      message: "Budget groups could not be loaded",
    });
  }
};

const isValidDateString = (value) => {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return false;
  }

  const date = new Date(`${value}T00:00:00.000Z`);
  return !Number.isNaN(date.getTime()) && value === date.toISOString().slice(0, 10);
};

const getMonthRange = (month) => {
  if (typeof month !== "string" || !/^\d{4}-\d{2}$/.test(month)) {
    return null;
  }

  const [year, monthNumber] = month.split("-").map(Number);

  if (monthNumber < 1 || monthNumber > 12) {
    return null;
  }

  const start = `${month}-01`;
  const nextMonthDate = new Date(Date.UTC(year, monthNumber, 1));
  const nextYear = nextMonthDate.getUTCFullYear();
  const nextMonth = String(nextMonthDate.getUTCMonth() + 1).padStart(2, "0");

  return {
    start,
    end: `${nextYear}-${nextMonth}-01`,
  };
};

const toNumber = (value) => Number(value || 0);

const getPersonalTransactions = async (req, res) => {
  try {
    await ensureBudgetSchema();

    const userId = req.user.userId;
    const range = getMonthRange(req.query.month);

    if (!range) {
      return res.status(400).json({
        message: "Valid month query parameter is required",
      });
    }

    const summaryResult = await pool.query(
      `
      SELECT
        COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0)::float AS income_total,
        COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0)::float AS expense_total
      FROM budget_transactions
      WHERE user_id = $1
        AND transaction_date >= $2
        AND transaction_date < $3
      `,
      [userId, range.start, range.end]
    );

    const transactionsResult = await pool.query(
      `
      SELECT
        id,
        type,
        title,
        amount::float AS amount,
        transaction_date,
        note
      FROM budget_transactions
      WHERE user_id = $1
        AND transaction_date >= $2
        AND transaction_date < $3
      ORDER BY transaction_date DESC, id DESC
      `,
      [userId, range.start, range.end]
    );

    const incomeTotal = toNumber(summaryResult.rows[0]?.income_total);
    const expenseTotal = toNumber(summaryResult.rows[0]?.expense_total);
    const sharedExpenseTotal = 0;

    return res.status(200).json({
      summary: {
        income_total: incomeTotal,
        expense_total: expenseTotal,
        shared_expense_total: sharedExpenseTotal,
        remaining_balance: incomeTotal - expenseTotal - sharedExpenseTotal,
      },
      transactions: transactionsResult.rows,
    });
  } catch (err) {
    console.error("GET PERSONAL BUDGET TRANSACTIONS ERROR:", err);

    return res.status(500).json({
      message: "Budget transactions could not be loaded",
    });
  }
};

const createPersonalTransaction = async (req, res) => {
  try {
    await ensureBudgetSchema();

    const userId = req.user.userId;
    const type = req.body.type?.trim();
    const title = req.body.title?.trim();
    const amount = Number(req.body.amount);
    const transactionDate = req.body.transaction_date;
    const note = req.body.note?.trim() || null;

    if (!["income", "expense"].includes(type)) {
      return res.status(400).json({
        message: "Invalid transaction type",
      });
    }

    if (!title || !Number.isFinite(amount) || amount <= 0) {
      return res.status(400).json({
        message: "Invalid transaction details",
      });
    }

    if (!isValidDateString(transactionDate)) {
      return res.status(400).json({
        message: "Invalid transaction date",
      });
    }

    const result = await pool.query(
      `
      INSERT INTO budget_transactions
        (user_id, type, title, amount, transaction_date, note)
      VALUES
        ($1, $2, $3, $4, $5, $6)
      RETURNING
        id,
        type,
        title,
        amount::float AS amount,
        transaction_date,
        note
      `,
      [userId, type, title, amount, transactionDate, note]
    );

    return res.status(201).json({
      message: "Budget transaction created successfully",
      transaction: result.rows[0],
    });
  } catch (err) {
    console.error("CREATE PERSONAL BUDGET TRANSACTION ERROR:", err);

    return res.status(500).json({
      message: "Budget transaction could not be created",
    });
  }
};

const createBudgetGroup = async (req, res) => {
  await ensureBudgetSchema();

  const client = await pool.connect();

  try {
    const userId = req.user.userId;
    const name = req.body.name?.trim();
    const memberIds = req.body.memberIds;

    if (!name) {
      return res.status(400).json({
        message: "Group name is required",
      });
    }

    if (!Array.isArray(memberIds) || memberIds.length === 0) {
      return res.status(400).json({
        message: "At least one friend must be selected",
      });
    }

    const uniqueMemberIds = [...new Set(memberIds.map(Number))];
    const hasInvalidMember = uniqueMemberIds.some(
      (memberId) => !Number.isInteger(memberId) || memberId <= 0
    );

    if (hasInvalidMember || uniqueMemberIds.includes(userId)) {
      return res.status(400).json({
        message: "Invalid group members",
      });
    }

    await client.query("BEGIN");

    const acceptedResult = await client.query(
      `
      SELECT
        CASE
          WHEN requester_id = $1 THEN addressee_id
          ELSE requester_id
        END AS friend_id
      FROM friendships
      WHERE status = 'accepted'
        AND (requester_id = $1 OR addressee_id = $1)
        AND (
          CASE
            WHEN requester_id = $1 THEN addressee_id
            ELSE requester_id
          END
        ) = ANY($2::int[])
      `,
      [userId, uniqueMemberIds]
    );

    const acceptedFriendIds = new Set(
      acceptedResult.rows.map((row) => Number(row.friend_id))
    );
    const allMembersAccepted = uniqueMemberIds.every((memberId) =>
      acceptedFriendIds.has(memberId)
    );

    if (!allMembersAccepted) {
      await client.query("ROLLBACK");
      return res.status(403).json({
        message: "Only accepted friends can be added to a group",
      });
    }

    const groupResult = await client.query(
      `
      INSERT INTO budget_groups (name, created_by)
      VALUES ($1, $2)
      RETURNING id, name, created_by, created_at
      `,
      [name, userId]
    );

    const group = groupResult.rows[0];
    const allMemberIds = [userId, ...uniqueMemberIds];

    for (const memberId of allMemberIds) {
      await client.query(
        `
        INSERT INTO budget_group_members (group_id, user_id)
        VALUES ($1, $2)
        ON CONFLICT (group_id, user_id) DO NOTHING
        `,
        [group.id, memberId]
      );
    }

    const membersResult = await client.query(
      `
      SELECT id, first_name, last_name, email
      FROM users
      WHERE id = ANY($1::int[])
      ORDER BY
        CASE WHEN id = $2 THEN 0 ELSE 1 END,
        first_name ASC,
        last_name ASC
      `,
      [allMemberIds, userId]
    );

    await client.query("COMMIT");

    return res.status(201).json({
      message: "Budget group created successfully",
      group: {
        ...group,
        members: membersResult.rows,
      },
    });
  } catch (err) {
    await client.query("ROLLBACK");

    console.error("CREATE BUDGET GROUP ERROR:", err);

    return res.status(500).json({
      message: "Budget group could not be created",
    });
  } finally {
    client.release();
  }
};

module.exports = {
  getAcceptedFriends,
  getPersonalTransactions,
  createPersonalTransaction,
  getBudgetGroups,
  createBudgetGroup,
};
