const { poolPromise, sql } = require("../config/db");

const createHabit = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { name, description, period, frequency_type, days } = req.body;

    if (
      !name ||
      !period ||
      !frequency_type ||
      !days ||
      !Array.isArray(days) ||
      days.length === 0
    ) {
      return res.status(400).json({
        message: "Missing required fields",
      });
    }

    const validPeriods = ["morning", "all", "evening"];
    if (!validPeriods.includes(period)) {
      return res.status(400).json({
        message: "Invalid period value",
      });
    }

    const validFrequencyTypes = ["daily", "weekly"];
    if (!validFrequencyTypes.includes(frequency_type)) {
      return res.status(400).json({
        message: "Invalid frequency_type value",
      });
    }

    const areDaysValid = days.every(
      (day) => Number.isInteger(day) && day >= 1 && day <= 7
    );

    if (!areDaysValid) {
      return res.status(400).json({
        message: "Days must be integers between 1 and 7",
      });
    }

    const pool = await poolPromise;

    const habitResult = await pool
      .request()
      .input("userId", sql.Int, userId)
      .input("name", sql.NVarChar(255), name)
      .input("description", sql.NVarChar(500), description || null)
      .input("period", sql.NVarChar(20), period)
      .input("frequencyType", sql.NVarChar(50), frequency_type)
      .query(`
        INSERT INTO habits (user_id, name, description, frequency_type, period)
        OUTPUT INSERTED.id
        VALUES (@userId, @name, @description, @frequencyType, @period)
      `);

    const habitId = habitResult.recordset[0].id;

    for (const day of days) {
      await pool
        .request()
        .input("habitId", sql.Int, habitId)
        .input("dayOfWeek", sql.Int, day)
        .query(`
          INSERT INTO habit_days (habit_id, day_of_week)
          VALUES (@habitId, @dayOfWeek)
        `);
    }

    return res.status(201).json({
      message: "Habit created successfully",
      habitId,
    });
  } catch (err) {
    console.error("CREATE HABIT ERROR:", err);
    return res.status(500).json({
      message: "Server error",
    });
  }
};

const getHabits = async (req, res) => {
  console.log("GET /habits çalıştı");

  try {
    const userId = req.user.userId;
    const { date } = req.query; // örnek: 2026-04-23

    if (!date) {
      return res.status(400).json({
        message: "date query parameter is required",
      });
    }

    const pool = await poolPromise;
    console.log("DB query başlamadan önce");

    const result = await pool
      .request()
      .input("userId", sql.Int, userId)
      .input("selectedDate", sql.Date, date)
      .query(`
        SELECT
          h.id,
          h.name,
          h.description,
          h.period,
          h.frequency_type,
         hd.day_of_week,
          CASE
           WHEN hl.id IS NOT NULL THEN CAST(1 AS BIT)
           ELSE CAST(0 AS BIT)
           END AS is_completed
         FROM habits h
        LEFT JOIN habit_days hd 
          ON h.id = hd.habit_id
        LEFT JOIN habit_logs hl
         ON h.id = hl.habit_id
         AND hl.user_id = @userId
         AND hl.log_date = @selectedDate
       WHERE h.user_id = @userId
        ORDER BY h.id DESC, hd.day_of_week ASC
       `);

    console.log("DB query bitti");
    console.log(result.recordset);

    const groupedHabits = [];

    for (const row of result.recordset) {
      let habit = groupedHabits.find((item) => item.id === row.id);

      if (!habit) {
        habit = {
          id: row.id,
          name: row.name,
          description: row.description,
          period: row.period,
          frequency_type: row.frequency_type,
          days: [],
          is_completed: row.is_completed === true || row.is_completed === 1,
        };
        groupedHabits.push(habit);
      }

      if (row.day_of_week !== null) {
        habit.days.push(row.day_of_week);
      }
    }

    return res.status(200).json({
      habits: groupedHabits,
    });
  } catch (err) {
    console.error("GET HABITS ERROR:", err);
    return res.status(500).json({
      message: "Server error",
    });
  }
};

module.exports = { createHabit, getHabits };