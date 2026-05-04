const { poolPromise, sql } = require("../config/db");

const toggleHabitLog = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { habit_id, log_date } = req.body;

    if (!habit_id || !log_date) {
      return res.status(400).json({
        message: "habit_id and log_date are required",
      });
    }

    const pool = await poolPromise;

    const existingLog = await pool
      .request()
      .input("habitId", sql.Int, habit_id)
      .input("userId", sql.Int, userId)
      .input("logDate", sql.Date, log_date)
      .query(`
        SELECT id
        FROM habit_logs
        WHERE habit_id = @habitId
          AND user_id = @userId
          AND log_date = @logDate
      `);

    if (existingLog.recordset.length > 0) {
      await pool
        .request()
        .input("habitId", sql.Int, habit_id)
        .input("userId", sql.Int, userId)
        .input("logDate", sql.Date, log_date)
        .query(`
          DELETE FROM habit_logs
          WHERE habit_id = @habitId
            AND user_id = @userId
            AND log_date = @logDate
        `);

      return res.status(200).json({
        completed: false,
        message: "Habit log removed",
      });
    }

    await pool
      .request()
      .input("habitId", sql.Int, habit_id)
      .input("userId", sql.Int, userId)
      .input("logDate", sql.Date, log_date)
      .input("value", sql.Int, 1)
      .query(`
        INSERT INTO habit_logs (habit_id, user_id, log_date, value)
        VALUES (@habitId, @userId, @logDate, @value)
      `);

    return res.status(201).json({
      completed: true,
      message: "Habit log created",
    });
  } catch (err) {
    console.error("TOGGLE HABIT LOG ERROR:", err);
    return res.status(500).json({
      message: "Server error",
    });
  }
};

module.exports = { toggleHabitLog };