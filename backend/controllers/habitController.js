const pool = require("../config/db");

let habitSourceColumnsReadyPromise;

const ensureHabitSourceColumns = () => {
  if (!habitSourceColumnsReadyPromise) {
    habitSourceColumnsReadyPromise = pool.query(`
      ALTER TABLE habits
      ADD COLUMN IF NOT EXISTS source_template_id TEXT;

      ALTER TABLE habits
      ADD COLUMN IF NOT EXISTS source_template_title VARCHAR(255);

      DO $$
      BEGIN
        IF EXISTS (
          SELECT 1 FROM information_schema.tables
          WHERE table_name = 'user_template_additions'
        ) AND EXISTS (
          SELECT 1 FROM information_schema.tables
          WHERE table_name = 'habit_templates'
        ) AND EXISTS (
          SELECT 1 FROM information_schema.tables
          WHERE table_name = 'template_habits'
        ) THEN
          UPDATE habits h
          SET
            source_template_id = ht.id::text,
            source_template_title = ht.title
          FROM user_template_additions uta
          JOIN habit_templates ht
            ON uta.template_id = ht.id::text
          JOIN template_habits th
            ON th.template_id = ht.id
          WHERE h.user_id = uta.user_id
            AND h.name = th.name
            AND h.source_template_id IS NULL;
        END IF;
      END $$;
    `);
  }

  return habitSourceColumnsReadyPromise;
};

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
    await ensureHabitSourceColumns();

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
        h.source_template_id,
        h.source_template_title,
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
          source_template_id: row.source_template_id,
          source_template_title: row.source_template_title,
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

const formatDate = (value) => {
  if (value instanceof Date) {
    return value.toISOString().slice(0, 10);
  }

  return value?.toString().slice(0, 10);
};

const getHabitSummary = async (req, res) => {
  try {
    const userId = req.user.userId;
    const days = Number(req.query.days || 30);
    const endDate = req.query.end_date;

    if (!Number.isInteger(days) || days < 1 || days > 90) {
      return res.status(400).json({
        message: "days must be an integer between 1 and 90",
      });
    }

    if (!endDate || !/^\d{4}-\d{2}-\d{2}$/.test(endDate)) {
      return res.status(400).json({
        message: "end_date is required in YYYY-MM-DD format",
      });
    }

    const result = await pool.query(
      `
      WITH date_range AS (
        SELECT generate_series(
          $2::date - (($3::int - 1) * interval '1 day'),
          $2::date,
          interval '1 day'
        )::date AS log_date
      ),
      planned AS (
        SELECT
          d.log_date,
          h.id AS habit_id,
          h.target_value
        FROM date_range d
        JOIN habits h
          ON h.user_id = $1
          AND h.created_at::date <= d.log_date
        JOIN habit_days hd
          ON hd.habit_id = h.id
          AND hd.day_of_week = EXTRACT(ISODOW FROM d.log_date)::int
      ),
      evaluated AS (
        SELECT
          p.log_date,
          CASE
            WHEN p.target_value IS NOT NULL THEN COALESCE(hl.value, 0) >= p.target_value
            ELSE hl.id IS NOT NULL
          END AS is_completed
        FROM planned p
        LEFT JOIN habit_logs hl
          ON hl.habit_id = p.habit_id
          AND hl.user_id = $1
          AND hl.log_date = p.log_date
      )
      SELECT
        log_date,
        COUNT(*)::int AS planned_count,
        COUNT(*) FILTER (WHERE is_completed)::int AS completed_count,
        COUNT(*) FILTER (WHERE NOT is_completed)::int AS missed_count
      FROM evaluated
      GROUP BY log_date
      ORDER BY log_date ASC
      `,
      [userId, endDate, days]
    );

    const daysSummary = result.rows.map((row) => ({
      date: formatDate(row.log_date),
      planned: Number(row.planned_count),
      completed: Number(row.completed_count),
      missed: Number(row.missed_count),
    }));
    const totalPlanned = daysSummary.reduce((sum, day) => sum + day.planned, 0);
    const completed = daysSummary.reduce((sum, day) => sum + day.completed, 0);
    const missed = daysSummary.reduce((sum, day) => sum + day.missed, 0);
    const completionRate =
      totalPlanned === 0 ? 0 : Math.round((completed / totalPlanned) * 100);

    return res.status(200).json({
      summary: {
        totalPlanned,
        completed,
        missed,
        completionRate,
        days: daysSummary,
      },
    });
  } catch (err) {
    console.error("GET HABIT SUMMARY ERROR:", err);

    return res.status(500).json({
      message: "Server error",
    });
  }
};

const deleteHabit = async (req, res) => {
  const habitId = Number(req.params.id);

  if (!Number.isInteger(habitId) || habitId <= 0) {
    return res.status(400).json({
      message: "Invalid habit id",
    });
  }

  const client = await pool.connect();

  try {
    const userId = req.user.userId;

    await client.query("BEGIN");

    const habitResult = await client.query(
      `
      SELECT id
      FROM habits
      WHERE id = $1 AND user_id = $2
      `,
      [habitId, userId]
    );

    if (habitResult.rows.length === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({
        message: "Habit not found",
      });
    }

    await client.query(
      `
      DELETE FROM habit_logs
      WHERE habit_id = $1 AND user_id = $2
      `,
      [habitId, userId]
    );

    await client.query(
      `
      DELETE FROM habit_days
      WHERE habit_id = $1
      `,
      [habitId]
    );

    await client.query(
      `
      DELETE FROM habits
      WHERE id = $1 AND user_id = $2
      `,
      [habitId, userId]
    );

    await client.query("COMMIT");

    return res.status(200).json({
      message: "Habit deleted successfully",
    });
  } catch (err) {
    await client.query("ROLLBACK");

    console.error("DELETE HABIT ERROR:", err);

    return res.status(500).json({
      message: "Server error",
    });
  } finally {
    client.release();
  }
};

module.exports = { createHabit, getHabits, getHabitSummary, deleteHabit };
