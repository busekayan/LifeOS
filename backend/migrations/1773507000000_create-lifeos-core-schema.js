exports.up = (pgm) => {
  pgm.createTable("habits", {
    id: "id",
    user_id: {
      type: "integer",
      notNull: true,
      references: "users(id)",
      onDelete: "CASCADE",
    },
    name: {
      type: "varchar(255)",
      notNull: true,
    },
    emoji: {
      type: "varchar(10)",
      notNull: true,
      default: "✨",
    },
    description: {
      type: "varchar(500)",
    },
    frequency_type: {
      type: "varchar(50)",
      notNull: true,
    },
    period: {
      type: "varchar(20)",
      notNull: true,
      default: "all",
    },
    target_value: {
      type: "integer",
    },
    goal_unit: {
      type: "varchar(20)",
    },
    source_template_id: {
      type: "text",
    },
    source_template_title: {
      type: "varchar(255)",
    },
    created_at: {
      type: "timestamp",
      notNull: true,
      default: pgm.func("current_timestamp"),
    },
  });

  pgm.addConstraint("habits", "chk_habits_period", {
    check: "period IN ('morning', 'all', 'evening')",
  });
  pgm.addConstraint("habits", "chk_habits_frequency_type", {
    check: "frequency_type IN ('daily', 'weekly')",
  });
  pgm.addConstraint("habits", "chk_habits_goal_unit", {
    check:
      "goal_unit IN ('minute', 'hour', 'step', 'liter', 'count') OR goal_unit IS NULL",
  });

  pgm.createTable("habit_days", {
    id: "id",
    habit_id: {
      type: "integer",
      notNull: true,
      references: "habits(id)",
      onDelete: "CASCADE",
    },
    day_of_week: {
      type: "integer",
      notNull: true,
    },
  });
  pgm.addConstraint("habit_days", "chk_habit_days_day_of_week", {
    check: "day_of_week BETWEEN 1 AND 7",
  });
  pgm.addConstraint("habit_days", "uq_habit_days_habit_day", {
    unique: ["habit_id", "day_of_week"],
  });

  pgm.createTable("habit_logs", {
    id: "id",
    habit_id: {
      type: "integer",
      notNull: true,
      references: "habits(id)",
      onDelete: "CASCADE",
    },
    user_id: {
      type: "integer",
      notNull: true,
      references: "users(id)",
      onDelete: "CASCADE",
    },
    value: {
      type: "integer",
      notNull: true,
      default: 1,
    },
    log_date: {
      type: "date",
      notNull: true,
    },
    created_at: {
      type: "timestamp",
      notNull: true,
      default: pgm.func("current_timestamp"),
    },
  });
  pgm.addConstraint("habit_logs", "chk_habit_logs_value", {
    check: "value >= 0",
  });
  pgm.addConstraint("habit_logs", "uq_habit_logs_habit_user_date", {
    unique: ["habit_id", "user_id", "log_date"],
  });

  pgm.createTable("refresh_tokens", {
    id: "id",
    user_id: {
      type: "integer",
      notNull: true,
      references: "users(id)",
      onDelete: "CASCADE",
    },
    token: {
      type: "text",
      notNull: true,
    },
    expires_at: {
      type: "timestamp",
      notNull: true,
    },
    is_revoked: {
      type: "boolean",
      notNull: true,
      default: false,
    },
    created_at: {
      type: "timestamp",
      notNull: true,
      default: pgm.func("current_timestamp"),
    },
  });

  pgm.createTable("mood_logs", {
    id: "id",
    user_id: {
      type: "integer",
      notNull: true,
      references: "users(id)",
      onDelete: "CASCADE",
    },
    mood: {
      type: "varchar(20)",
      notNull: true,
    },
    log_date: {
      type: "date",
      notNull: true,
    },
    created_at: {
      type: "timestamp",
      notNull: true,
      default: pgm.func("current_timestamp"),
    },
    updated_at: {
      type: "timestamp",
      notNull: true,
      default: pgm.func("current_timestamp"),
    },
  });
  pgm.addConstraint("mood_logs", "chk_mood_logs_mood", {
    check:
      "mood IN ('mutlu', 'sakin', 'enerjik', 'uzgun', 'stresli', 'yorgun')",
  });
  pgm.addConstraint("mood_logs", "uq_mood_logs_user_date", {
    unique: ["user_id", "log_date"],
  });

  pgm.sql(`
    CREATE OR REPLACE FUNCTION update_timestamp()
    RETURNS TRIGGER AS $$
    BEGIN
      NEW.updated_at = CURRENT_TIMESTAMP;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
  `);
  pgm.sql(`
    CREATE TRIGGER mood_logs_updated_at
    BEFORE UPDATE ON mood_logs
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();
  `);

  pgm.createTable("daily_questions", {
    id: "id",
    question: {
      type: "text",
      notNull: true,
    },
    created_at: {
      type: "timestamp",
      notNull: true,
      default: pgm.func("current_timestamp"),
    },
  });

  pgm.createTable("diaries", {
    id: "id",
    user_id: {
      type: "integer",
      notNull: true,
      references: "users(id)",
      onDelete: "CASCADE",
    },
    content: {
      type: "text",
      notNull: true,
    },
    date: {
      type: "date",
      notNull: true,
    },
    created_at: {
      type: "timestamp",
      notNull: true,
      default: pgm.func("current_timestamp"),
    },
    updated_at: {
      type: "timestamp",
      notNull: true,
      default: pgm.func("current_timestamp"),
    },
  });
  pgm.addConstraint("diaries", "uq_diaries_user_date", {
    unique: ["user_id", "date"],
  });

  pgm.createTable("template_categories", {
    id: "id",
    name: {
      type: "varchar(100)",
      notNull: true,
      unique: true,
    },
    emoji: {
      type: "varchar(10)",
      notNull: true,
    },
    display_order: {
      type: "integer",
      notNull: true,
      unique: true,
    },
  });

  pgm.createTable("habit_templates", {
    id: "id",
    category_id: {
      type: "integer",
      notNull: true,
      references: "template_categories(id)",
      onDelete: "CASCADE",
    },
    title: {
      type: "varchar(255)",
      notNull: true,
    },
    description: {
      type: "text",
      notNull: true,
    },
    image_url: {
      type: "text",
    },
    estimated_duration_days: {
      type: "integer",
      notNull: true,
      default: 30,
    },
    is_featured: {
      type: "boolean",
      notNull: true,
      default: false,
    },
    display_order: {
      type: "integer",
      notNull: true,
    },
  });
  pgm.addConstraint("habit_templates", "uq_habit_templates_category_order", {
    unique: ["category_id", "display_order"],
  });

  pgm.createTable("template_habits", {
    id: "id",
    template_id: {
      type: "integer",
      notNull: true,
      references: "habit_templates(id)",
      onDelete: "CASCADE",
    },
    name: {
      type: "varchar(255)",
      notNull: true,
    },
    description: {
      type: "varchar(500)",
    },
    period: {
      type: "varchar(20)",
      notNull: true,
      default: "all",
    },
    frequency_type: {
      type: "varchar(50)",
      notNull: true,
      default: "weekly",
    },
    days: {
      type: "integer[]",
      notNull: true,
      default: pgm.func("ARRAY[1,2,3,4,5,6,7]"),
    },
    target_value: {
      type: "integer",
    },
    goal_unit: {
      type: "varchar(20)",
    },
    display_order: {
      type: "integer",
      notNull: true,
    },
  });
  pgm.addConstraint("template_habits", "chk_template_habits_period", {
    check: "period IN ('morning', 'all', 'evening')",
  });
  pgm.addConstraint("template_habits", "chk_template_habits_frequency_type", {
    check: "frequency_type IN ('daily', 'weekly')",
  });
  pgm.addConstraint("template_habits", "chk_template_habits_goal_unit", {
    check:
      "goal_unit IN ('minute', 'hour', 'step', 'liter', 'count') OR goal_unit IS NULL",
  });
  pgm.addConstraint("template_habits", "uq_template_habits_template_order", {
    unique: ["template_id", "display_order"],
  });

  pgm.createTable("user_template_additions", {
    id: "id",
    user_id: {
      type: "integer",
      notNull: true,
      references: "users(id)",
      onDelete: "CASCADE",
    },
    template_id: {
      type: "text",
      notNull: true,
    },
    created_at: {
      type: "timestamp",
      notNull: true,
      default: pgm.func("current_timestamp"),
    },
  });
  pgm.addConstraint("user_template_additions", "uq_user_template_additions", {
    unique: ["user_id", "template_id"],
  });

  pgm.createIndex("habit_days", "habit_id");
  pgm.createIndex("habit_logs", ["user_id", "log_date"]);
  pgm.createIndex("mood_logs", ["user_id", "log_date"]);
  pgm.createIndex("diaries", ["user_id", "date"]);
  pgm.createIndex("habit_templates", "category_id");
  pgm.createIndex("template_habits", "template_id");

  pgm.sql(`
    INSERT INTO template_categories (id, name, emoji, display_order)
    VALUES
      (1, 'Fitness', '🏋️', 1),
      (2, 'Productivity', '⚡', 2),
      (3, 'Wellness', '🧘', 3),
      (4, 'Learning', '📚', 4);

    INSERT INTO habit_templates
      (id, category_id, title, description, image_url, estimated_duration_days, is_featured, display_order)
    VALUES
      (
        1,
        1,
        'Sabah Savaşçısı',
        'Güne hareket, enerji ve düzenle başlamak için kısa bir sabah rutini.',
        'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=400',
        30,
        TRUE,
        1
      ),
      (
        2,
        2,
        'Derin Odaklanma',
        'Dikkatini korumak ve günü planlı ilerletmek için üretkenlik rutini.',
        'https://images.unsplash.com/photo-1484480974693-6ca0a78fb36b?w=400',
        30,
        TRUE,
        1
      ),
      (
        3,
        3,
        'Huzurlu Akşamlar',
        'Günü sakin kapatmak, zihni boşaltmak ve uykuya hazırlanmak için akşam rutini.',
        'https://images.unsplash.com/photo-1506126613408-eca07ce68773?w=400',
        30,
        TRUE,
        1
      ),
      (
        4,
        1,
        'Güçlü Beden',
        'Daha aktif kalmak ve temel sağlık alışkanlıklarını düzenli takip etmek için plan.',
        'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400',
        30,
        FALSE,
        2
      ),
      (
        5,
        4,
        'Okuma Ritüeli',
        'Düzenli okuma, not alma ve öğrenmeyi kalıcı hale getirme rutini.',
        'https://images.unsplash.com/photo-1481627834876-b7833e8f5570?w=400',
        30,
        FALSE,
        1
      );

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
  `);
};

exports.down = (pgm) => {
  pgm.dropTable("user_template_additions");
  pgm.dropTable("template_habits");
  pgm.dropTable("habit_templates");
  pgm.dropTable("template_categories");
  pgm.dropTable("diaries");
  pgm.dropTable("daily_questions");
  pgm.sql("DROP TRIGGER IF EXISTS mood_logs_updated_at ON mood_logs;");
  pgm.dropTable("mood_logs");
  pgm.sql("DROP FUNCTION IF EXISTS update_timestamp();");
  pgm.dropTable("refresh_tokens");
  pgm.dropTable("habit_logs");
  pgm.dropTable("habit_days");
  pgm.dropTable("habits");
};
