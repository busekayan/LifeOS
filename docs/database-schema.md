# Database Schema

## users
- id: integer, primary key, not null
- email: varchar, unique, not null
- password_hash: varchar, not null
- full_name: varchar, nullable
- created_at: timestamp, not null

## habits
- id: integer, primary key, not null
- user_id: integer, foreign key -> users.id, not null
- title: varchar, not null
- goal_type: varchar, not null
- goal_value: integer, not null
- created_at: timestamp, not null

## habit_logs
- id: integer, primary key, not null
- habit_id: integer, foreign key -> habits.id, not null
- log_date: date, not null
- value: integer, not null
- created_at: timestamp, not null