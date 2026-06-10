# Database Schema

This document describes the current PostgreSQL schema used by the LifeOS backend.

## users
- id: integer, primary key
- first_name: varchar(100), required
- last_name: varchar(100), required
- email: varchar(255), unique, required
- password_hash: varchar(255), required
- created_at: timestamp

## habits
- id: integer, primary key
- user_id: foreign key -> users.id
- name: varchar(255), required
- description: varchar(500), optional
- frequency_type: daily or weekly
- period: morning, all, or evening
- target_value: integer, optional
- goal_unit: minute, hour, step, liter, count, or null
- created_at: timestamp

## habit_days
- id: integer, primary key
- habit_id: foreign key -> habits.id
- day_of_week: integer from 1 to 7
- unique: habit_id + day_of_week

## habit_logs
- id: integer, primary key
- habit_id: foreign key -> habits.id
- user_id: foreign key -> users.id
- value: integer, default 1
- log_date: date
- created_at: timestamp
- unique: habit_id + user_id + log_date

## refresh_tokens
- id: integer, primary key
- user_id: foreign key -> users.id
- token: text
- expires_at: timestamp
- is_revoked: boolean
- created_at: timestamp

## mood_logs
- id: integer, primary key
- user_id: foreign key -> users.id
- mood: mutlu, sakin, enerjik, uzgun, stresli, or yorgun
- log_date: date
- created_at: timestamp
- updated_at: timestamp
- unique: user_id + log_date

## daily_questions
- id: integer, primary key
- question: text
- created_at: timestamp

## diaries
- id: integer, primary key
- user_id: foreign key -> users.id
- content: text
- date: date
- created_at: timestamp
- updated_at: timestamp
- unique: user_id + date

## template_categories
- id: integer, primary key
- name: varchar(100), unique
- emoji: varchar(10)
- display_order: integer, unique

## habit_templates
- id: integer, primary key
- category_id: foreign key -> template_categories.id
- title: varchar(255)
- description: text
- image_url: text, optional
- estimated_duration_days: integer
- is_featured: boolean
- display_order: integer
- unique: category_id + display_order

## template_habits
- id: integer, primary key
- template_id: foreign key -> habit_templates.id
- name: varchar(255)
- emoji: varchar(10)
- description: varchar(500), optional
- period: morning, all, or evening
- frequency_type: daily or weekly
- days: integer array
- target_value: integer, optional
- goal_unit: minute, hour, step, liter, count, or null
- display_order: integer
- unique: template_id + display_order

## user_template_additions
- id: integer, primary key
- user_id: foreign key -> users.id
- template_id: text
- created_at: timestamp
- unique: user_id + template_id
