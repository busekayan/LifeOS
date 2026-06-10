-- LifeOS database schema

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE habits (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description VARCHAR(500),
    frequency_type VARCHAR(50) NOT NULL,
    period VARCHAR(20) NOT NULL DEFAULT 'all',
    target_value INTEGER,
    goal_unit VARCHAR(20),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_habits_frequency_type
        CHECK (frequency_type IN ('daily', 'weekly')),
    CONSTRAINT chk_habits_period
        CHECK (period IN ('morning', 'all', 'evening')),
    CONSTRAINT chk_habits_goal_unit
        CHECK (goal_unit IN ('minute', 'hour', 'step', 'liter', 'count') OR goal_unit IS NULL)
);

CREATE TABLE habit_days (
    id SERIAL PRIMARY KEY,
    habit_id INTEGER NOT NULL REFERENCES habits(id) ON DELETE CASCADE,
    day_of_week INTEGER NOT NULL,

    CONSTRAINT chk_habit_days_day_of_week
        CHECK (day_of_week BETWEEN 1 AND 7),
    CONSTRAINT uq_habit_days_habit_day
        UNIQUE (habit_id, day_of_week)
);

CREATE TABLE habit_logs (
    id SERIAL PRIMARY KEY,
    habit_id INTEGER NOT NULL REFERENCES habits(id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    value INTEGER NOT NULL DEFAULT 1,
    log_date DATE NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_habit_logs_value
        CHECK (value >= 0),
    CONSTRAINT uq_habit_logs_habit_user_date
        UNIQUE (habit_id, user_id, log_date)
);

CREATE TABLE refresh_tokens (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    is_revoked BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE mood_logs (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    mood VARCHAR(20) NOT NULL,
    log_date DATE NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_mood_logs_mood
        CHECK (mood IN ('mutlu', 'sakin', 'enerjik', 'uzgun', 'stresli', 'yorgun')),
    CONSTRAINT uq_mood_logs_user_date
        UNIQUE (user_id, log_date)
);

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
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE diaries (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    date DATE NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_diaries_user_date
        UNIQUE (user_id, date)
);

CREATE TABLE template_categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    emoji VARCHAR(10) NOT NULL,
    display_order INTEGER NOT NULL UNIQUE
);

CREATE TABLE habit_templates (
    id SERIAL PRIMARY KEY,
    category_id INTEGER NOT NULL REFERENCES template_categories(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    image_url TEXT,
    estimated_duration_days INTEGER NOT NULL DEFAULT 30,
    is_featured BOOLEAN NOT NULL DEFAULT FALSE,
    display_order INTEGER NOT NULL,

    CONSTRAINT uq_habit_templates_category_order
        UNIQUE (category_id, display_order)
);

CREATE TABLE template_habits (
    id SERIAL PRIMARY KEY,
    template_id INTEGER NOT NULL REFERENCES habit_templates(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    emoji VARCHAR(10) NOT NULL DEFAULT '✨',
    description VARCHAR(500),
    period VARCHAR(20) NOT NULL DEFAULT 'all',
    frequency_type VARCHAR(50) NOT NULL DEFAULT 'weekly',
    days INTEGER[] NOT NULL DEFAULT ARRAY[1,2,3,4,5,6,7],
    target_value INTEGER,
    goal_unit VARCHAR(20),
    display_order INTEGER NOT NULL,

    CONSTRAINT chk_template_habits_period
        CHECK (period IN ('morning', 'all', 'evening')),
    CONSTRAINT chk_template_habits_frequency_type
        CHECK (frequency_type IN ('daily', 'weekly')),
    CONSTRAINT chk_template_habits_goal_unit
        CHECK (goal_unit IN ('minute', 'hour', 'step', 'liter', 'count') OR goal_unit IS NULL),
    CONSTRAINT uq_template_habits_template_order
        UNIQUE (template_id, display_order)
);

CREATE TABLE user_template_additions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    template_id TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_user_template_additions
        UNIQUE (user_id, template_id)
);

CREATE INDEX idx_habit_days_habit_id
ON habit_days(habit_id);

CREATE INDEX idx_habit_logs_user_date
ON habit_logs(user_id, log_date);

CREATE INDEX idx_mood_logs_user_date
ON mood_logs(user_id, log_date);

CREATE INDEX idx_diaries_user_date
ON diaries(user_id, date);

CREATE INDEX idx_habit_templates_category
ON habit_templates(category_id);

CREATE INDEX idx_template_habits_template
ON template_habits(template_id);

-- Seed data for the Discover screen
INSERT INTO template_categories (id, name, emoji, display_order)
VALUES
    (1, 'Fitness', '🏋️', 1),
    (2, 'Productivity', '⚡', 2),
    (3, 'Wellness', '🧘', 3),
    (4, 'Learning', '📚', 4);

INSERT INTO habit_templates
    (id, category_id, title, description, image_url, estimated_duration_days, is_featured, display_order)
VALUES
    (1, 1, 'Sabah Savaşçısı', 'Güne hareket, enerji ve düzenle başlamak için kısa bir sabah rutini.', 'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=400', 30, TRUE, 1),
    (2, 2, 'Derin Odaklanma', 'Dikkatini korumak ve günü planlı ilerletmek için üretkenlik rutini.', 'https://images.unsplash.com/photo-1484480974693-6ca0a78fb36b?w=400', 30, TRUE, 1),
    (3, 3, 'Huzurlu Akşamlar', 'Günü sakin kapatmak, zihni boşaltmak ve uykuya hazırlanmak için akşam rutini.', 'https://images.unsplash.com/photo-1506126613408-eca07ce68773?w=400', 30, TRUE, 1),
    (4, 1, 'Güçlü Beden', 'Daha aktif kalmak ve temel sağlık alışkanlıklarını düzenli takip etmek için plan.', 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400', 30, FALSE, 2),
    (5, 4, 'Okuma Ritüeli', 'Düzenli okuma, not alma ve öğrenmeyi kalıcı hale getirme rutini.', 'https://images.unsplash.com/photo-1481627834876-b7833e8f5570?w=400', 30, FALSE, 1);

INSERT INTO template_habits
    (template_id, name, description, period, frequency_type, days, target_value, goal_unit, display_order)
VALUES
    (1, '7 AM Uyanış', 'Güne aynı saatte başlayarak ritmini sabitle.', 'morning', 'weekly', ARRAY[1,2,3,4,5], NULL, NULL, 1),
    (1, '10 dk Esneme', 'Kısa bir esneme ile bedeni uyandır.', 'morning', 'weekly', ARRAY[1,2,3,4,5,6,7], 10, 'minute', 2),
    (1, '20 dk Koşu', 'Hafif tempolu koşu veya yürüyüş yap.', 'morning', 'weekly', ARRAY[1,3,5], 20, 'minute', 3),
    (1, 'Soğuk Duş', 'Duşunu kısa ve canlandırıcı bir rutinle bitir.', 'morning', 'weekly', ARRAY[1,2,3,4,5], NULL, NULL, 4),
    (1, 'Sağlıklı Kahvaltı', 'Güne dengeli bir kahvaltı ile başla.', 'morning', 'weekly', ARRAY[1,2,3,4,5,6,7], NULL, NULL, 5),
    (2, 'Günü Planla', 'Başlamadan önce günün önceliklerini belirle.', 'morning', 'weekly', ARRAY[1,2,3,4,5], NULL, NULL, 1),
    (2, '90 dk Blok Çalışma', 'Tek bir işe bölünmeden odaklan.', 'all', 'weekly', ARRAY[1,2,3,4,5], 90, 'minute', 2),
    (2, 'Öğleye Kadar Telefon Yok', 'Sabah saatlerinde dikkatini koru.', 'morning', 'weekly', ARRAY[1,2,3,4,5], NULL, NULL, 3),
    (2, 'Gün Sonu Değerlendirmesi', 'Günün sonunda neyin iyi gittiğini yaz.', 'evening', 'weekly', ARRAY[1,2,3,4,5], NULL, NULL, 4),
    (3, '10 dk Meditasyon', 'Nefesine odaklanarak zihnini yavaşlat.', 'evening', 'weekly', ARRAY[1,2,3,4,5,6,7], 10, 'minute', 1),
    (3, 'Şükran Günlüğü', 'Bugün iyi gelen üç şeyi yaz.', 'evening', 'weekly', ARRAY[1,2,3,4,5,6,7], NULL, NULL, 2),
    (3, 'Ekransız Son Saat', 'Uyumadan önce ekranları kapat.', 'evening', 'weekly', ARRAY[1,2,3,4,5,6,7], NULL, NULL, 3),
    (4, 'Güç Antrenmanı', 'Haftada üç gün temel kuvvet çalışması yap.', 'all', 'weekly', ARRAY[1,3,5], NULL, NULL, 1),
    (4, 'Günlük Adım Hedefi', 'Gün içinde hareket etmeyi takip et.', 'all', 'weekly', ARRAY[1,2,3,4,5,6,7], 8000, 'step', 2),
    (4, 'Protein Takibi', 'Her gün protein hedefini takip et.', 'all', 'weekly', ARRAY[1,2,3,4,5,6,7], NULL, NULL, 3),
    (4, '8 Saat Uyku', 'Uyku düzenini korumaya çalış.', 'evening', 'weekly', ARRAY[1,2,3,4,5,6,7], 8, 'hour', 4),
    (5, '30 Sayfa Kitap Oku', 'Her gün düzenli okuma yap.', 'all', 'weekly', ARRAY[1,2,3,4,5,6,7], 30, 'count', 1),
    (5, 'Notlar Al', 'Önemli fikirleri kısa notlara dönüştür.', 'all', 'weekly', ARRAY[1,2,3,4,5,6,7], NULL, NULL, 2),
    (5, 'Haftalık Özet Çıkar', 'Hafta sonunda öğrendiklerini toparla.', 'evening', 'weekly', ARRAY[7], NULL, NULL, 3);

SELECT setval('template_categories_id_seq', (SELECT MAX(id) FROM template_categories));
SELECT setval('habit_templates_id_seq', (SELECT MAX(id) FROM habit_templates));
