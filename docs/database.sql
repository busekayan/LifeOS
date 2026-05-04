-- Users table
CREATE TABLE users (
    id INT IDENTITY(1,1) PRIMARY KEY,
    first_name NVARCHAR(100) NOT NULL,
    last_name NVARCHAR(100) NOT NULL,
    email NVARCHAR(255) NOT NULL UNIQUE,
    password_hash NVARCHAR(255) NOT NULL,
    created_at DATETIME2 DEFAULT GETDATE()
);

-- Habits table
CREATE TABLE habits (
    id INT IDENTITY(1,1) PRIMARY KEY,
    user_id INT NOT NULL,
    name NVARCHAR(255) NOT NULL,
    description NVARCHAR(500),
    frequency_type NVARCHAR(50) NOT NULL, -- daily, weekly
    period NVARCHAR(20) NOT NULL DEFAULT 'all', -- morning, all, evening
    target_value INT,
    created_at DATETIME2 DEFAULT GETDATE(),

    CONSTRAINT FK_habits_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
);

-- Habit days table
CREATE TABLE habit_days (
    id INT IDENTITY(1,1) PRIMARY KEY,
    habit_id INT NOT NULL,
    day_of_week INT NOT NULL, -- 1=Monday ... 7=Sunday

    CONSTRAINT FK_habit_days_habit
    FOREIGN KEY (habit_id) REFERENCES habits(id)
    ON DELETE CASCADE
);

-- Habit logs table
CREATE TABLE habit_logs (
    id INT IDENTITY(1,1) PRIMARY KEY,
    habit_id INT NOT NULL,
    value INT,
    log_date DATE NOT NULL,
    created_at DATETIME2 DEFAULT GETDATE(),

    CONSTRAINT FK_logs_habit
    FOREIGN KEY (habit_id) REFERENCES habits(id)
    ON DELETE CASCADE
);

-- Refresh token table
CREATE TABLE refresh_tokens (
    id INT IDENTITY(1,1) PRIMARY KEY,
    user_id INT NOT NULL,
    token NVARCHAR(MAX) NOT NULL,
    expires_at DATETIME NOT NULL,
    is_revoked BIT DEFAULT 0,
    created_at DATETIME DEFAULT GETDATE(),

    CONSTRAINT FK_refresh_tokens_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
);