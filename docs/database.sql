-- Users table
CREATE TABLE users (
    id INT IDENTITY(1,1) PRIMARY KEY,
    email NVARCHAR(255) NOT NULL UNIQUE,
    password_hash NVARCHAR(255) NOT NULL,
    created_at DATETIME2 DEFAULT GETDATE()
);

--Habits Table
CREATE TABLE habits (
    id INT IDENTITY(1,1) PRIMARY KEY,
    user_id INT NOT NULL,
    name NVARCHAR(255) NOT NULL,
    description NVARCHAR(500),
    frequency_type NVARCHAR(50) NOT NULL, -- daily, weekly, custom
    target_value INT,
    created_at DATETIME2 DEFAULT GETDATE(),

    CONSTRAINT FK_habits_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
);