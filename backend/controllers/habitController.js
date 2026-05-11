const pool = require("../config/db");

const createHabit = async (req, res) => {
  const client = await pool.connect();

  try {
    const userId = req.user.userId;
    const {
      name,
      description,
      period,
      frequency_type,
      days,
      target_value,
      goal_type,
    } = req.body;

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

    const hasTarget = target_value !== undefined && target_value !== null;
    const hasUnit = goal_type !== undefined && goal_type !== null;

    if (hasTarget !== hasUnit) {
      return res.status(400).json({
        message: "target_value and goal_type must be provided together",
      });
    }

    if (hasTarget) {
      if (!Number.isInteger(target_value) || target_value <= 0) {
        return res.status(400).json({
          message: "target_value must be a positive integer",
        });
      }

      const validUnits = ["minute", "hour", "step", "liter", "count"];
      if (!validUnits.includes(goal_type)) {
        return res.status(400).json({
          message: "Invalid goal_type value",
        });
      }
    }

    await client.query("BEGIN");

    const habitResult = await client.query(
      `
      INSERT INTO habits 
        (user_id, name, description, frequency_type, period, target_value, goal_unit)
      VALUES 
        ($1, $2, $3, $4, $5, $6, $7)
      RETURNING id
      `,
      [
        userId,
        name,
        description || null,
        frequency_type,
        period,
        hasTarget ? target_value : null,
        hasUnit ? goal_type : null,
      ]
    );

    const habitId = habitResult.rows[0].id;

    for (const day of days) {
      await client.query(
        `
        INSERT INTO habit_days 
          (habit_id, day_of_week)
        VALUES 
          ($1, $2)
        `,
        [habitId, day]
      );
    }

    await client.query("COMMIT");

    return res.status(201).json({
      message: "Habit created successfully",
      habitId,
    });
  } catch (err) {
    await client.query("ROLLBACK");

    console.error("CREATE HABIT ERROR:", err);

    return res.status(500).json({
      message: "Server error",
    });
  } finally {
    client.release();
  }
};

const getHabits = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { date } = req.query;

    if (!date) {
      return res.status(400).json({
        message: "date query parameter is required",
      });
    }

    const result = await pool.query(
      `
      SELECT
        h.id,
        h.name,
        h.description,
        h.period,
        h.frequency_type,
        h.target_value,
        h.goal_unit,
        hd.day_of_week,
        CASE
          WHEN h.target_value IS NOT NULL THEN
            COALESCE(hl.value, 0)
          ELSE
            CASE WHEN hl.id IS NOT NULL THEN 1 ELSE 0 END
        END AS current_value,
        CASE
          WHEN h.target_value IS NOT NULL THEN
            COALESCE(hl.value, 0) >= h.target_value
          ELSE
            hl.id IS NOT NULL
        END AS is_completed
      FROM habits h
      LEFT JOIN habit_days hd
        ON h.id = hd.habit_id
      LEFT JOIN habit_logs hl
        ON h.id = hl.habit_id
        AND hl.user_id = $1
        AND hl.log_date = $2
      WHERE h.user_id = $1
      ORDER BY h.id DESC, hd.day_of_week ASC
      `,
      [userId, date]
    );

    const groupedHabits = [];

    for (const row of result.rows) {
      let habit = groupedHabits.find((item) => item.id === row.id);

      if (!habit) {
        habit = {
          id: row.id,
          name: row.name,
          description: row.description,
          period: row.period,
          frequency_type: row.frequency_type,
          target_value: row.target_value,
          goal_type: row.goal_unit,
          current_value: row.current_value,
          is_completed: row.is_completed,
          days: [],
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