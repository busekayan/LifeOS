-- Users table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Habits table
CREATE TABLE habits (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    name VARCHAR(255) NOT NULL,
    description VARCHAR(500),
    frequency_type VARCHAR(50) NOT NULL,
    period VARCHAR(20) NOT NULL DEFAULT 'all',
    target_value INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_habits_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
);

-- Habit days table
CREATE TABLE habit_days (
    id SERIAL PRIMARY KEY,
    habit_id INTEGER NOT NULL,
    day_of_week INTEGER NOT NULL,

    CONSTRAINT fk_habit_days_habit
    FOREIGN KEY (habit_id) REFERENCES habits(id)
    ON DELETE CASCADE
);

-- Habit logs table
CREATE TABLE habit_logs (
    id SERIAL PRIMARY KEY,
    habit_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    value INTEGER DEFAULT 1,
    log_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_logs_habit
    FOREIGN KEY (habit_id) REFERENCES habits(id)
    ON DELETE CASCADE,

    CONSTRAINT fk_logs_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE

    
);
ALTER TABLE habit_logs
ADD CONSTRAINT uq_habit_logs_habit_user_date
UNIQUE (habit_id, user_id, log_date);

-- Refresh token table
CREATE TABLE refresh_tokens (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    token TEXT NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    is_revoked BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_refresh_tokens_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
);
-- habits tablosuna goal_unit ekle
ALTER TABLE habits
ADD COLUMN goal_unit VARCHAR(20) DEFAULT NULL;

-- goal_unit için check constraint (opsiyonel ama önerilen)
ALTER TABLE habits
ADD CONSTRAINT chk_goal_unit
CHECK (goal_unit IN ('minute', 'hour', 'step', 'liter', 'count') OR goal_unit IS NULL);

CREATE TABLE mood_logs (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    mood VARCHAR(20) NOT NULL,
    log_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_mood_logs_user
        FOREIGN KEY (user_id) REFERENCES users(id)
        ON DELETE CASCADE,

    CONSTRAINT uq_mood_logs_user_date
        UNIQUE (user_id, log_date),

    CONSTRAINT chk_mood
        CHECK (mood IN ('mutlu', 'sakin', 'enerjik', 'uzgun', 'stresli', 'yorgun'))
);

ALTER TABLE mood_logs
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
ADD CONSTRAINT mood_logs_user_date_unique
UNIQUE (user_id, log_date);
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER mood_logs_updated_at
BEFORE UPDATE ON mood_logs
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

CREATE TABLE daily_questions (
    id SERIAL PRIMARY KEY,
    question TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);
CREATE TABLE diaries (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL,
  content TEXT NOT NULL,
  date DATE NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE diaries
ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;