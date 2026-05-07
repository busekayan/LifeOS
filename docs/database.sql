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