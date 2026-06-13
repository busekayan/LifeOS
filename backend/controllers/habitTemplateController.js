const pool = require("../config/db");

let schemaReadyPromise;

const ensureHabitTemplateSchema = () => {
  if (!schemaReadyPromise) {
    schemaReadyPromise = pool.query(`
      CREATE TABLE IF NOT EXISTS template_categories (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        emoji VARCHAR(10) NOT NULL,
        display_order INTEGER NOT NULL UNIQUE
      );

      CREATE TABLE IF NOT EXISTS habit_templates (
        id SERIAL PRIMARY KEY,
        category_id INTEGER NOT NULL REFERENCES template_categories(id) ON DELETE CASCADE,
        title VARCHAR(255) NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        image_url TEXT,
        estimated_duration_days INTEGER NOT NULL DEFAULT 30,
        is_featured BOOLEAN NOT NULL DEFAULT FALSE,
        display_order INTEGER NOT NULL
      );

      ALTER TABLE habit_templates
      ADD COLUMN IF NOT EXISTS description TEXT NOT NULL DEFAULT '';

      ALTER TABLE habit_templates
      ADD COLUMN IF NOT EXISTS image_url TEXT;

      ALTER TABLE habit_templates
      ADD COLUMN IF NOT EXISTS estimated_duration_days INTEGER NOT NULL DEFAULT 30;

      ALTER TABLE habit_templates
      ADD COLUMN IF NOT EXISTS is_featured BOOLEAN NOT NULL DEFAULT FALSE;

      CREATE TABLE IF NOT EXISTS template_habits (
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
        display_order INTEGER NOT NULL
      );

      ALTER TABLE template_habits
      ADD COLUMN IF NOT EXISTS description VARCHAR(500);

      ALTER TABLE template_habits
      ADD COLUMN IF NOT EXISTS emoji VARCHAR(10) NOT NULL DEFAULT '✨';

      ALTER TABLE template_habits
      ALTER COLUMN emoji SET DEFAULT '✨';

      ALTER TABLE template_habits
      ALTER COLUMN frequency SET DEFAULT 'weekly';

      ALTER TABLE template_habits
      ADD COLUMN IF NOT EXISTS period VARCHAR(20) NOT NULL DEFAULT 'all';

      ALTER TABLE template_habits
      ADD COLUMN IF NOT EXISTS frequency_type VARCHAR(50) NOT NULL DEFAULT 'weekly';

      ALTER TABLE template_habits
      ADD COLUMN IF NOT EXISTS days INTEGER[] NOT NULL DEFAULT ARRAY[1,2,3,4,5,6,7];

      ALTER TABLE template_habits
      ADD COLUMN IF NOT EXISTS target_value INTEGER;

      ALTER TABLE template_habits
      ADD COLUMN IF NOT EXISTS goal_unit VARCHAR(20);

      ALTER TABLE habits
      ADD COLUMN IF NOT EXISTS source_template_id TEXT;

      ALTER TABLE habits
      ADD COLUMN IF NOT EXISTS source_template_title VARCHAR(255);

      CREATE TABLE IF NOT EXISTS user_template_additions (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        template_id TEXT NOT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE (user_id, template_id)
      );

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

      INSERT INTO template_categories (name, emoji, display_order)
      SELECT
        'Fitness',
        '🏋️',
        COALESCE((SELECT MAX(display_order) FROM template_categories), 0) + 1
      WHERE NOT EXISTS (SELECT 1 FROM template_categories WHERE name = 'Fitness');

      INSERT INTO template_categories (name, emoji, display_order)
      SELECT
        'Productivity',
        '⚡',
        COALESCE((SELECT MAX(display_order) FROM template_categories), 0) + 1
      WHERE NOT EXISTS (SELECT 1 FROM template_categories WHERE name = 'Productivity');

      INSERT INTO template_categories (name, emoji, display_order)
      SELECT
        'Wellness',
        '🧘',
        COALESCE((SELECT MAX(display_order) FROM template_categories), 0) + 1
      WHERE NOT EXISTS (SELECT 1 FROM template_categories WHERE name = 'Wellness');

      INSERT INTO template_categories (name, emoji, display_order)
      SELECT
        'Learning',
        '📚',
        COALESCE((SELECT MAX(display_order) FROM template_categories), 0) + 1
      WHERE NOT EXISTS (SELECT 1 FROM template_categories WHERE name = 'Learning');

      INSERT INTO habit_templates
        (category_id, title, description, image_url, estimated_duration_days, is_featured, display_order)
      SELECT
        tc.id,
        'Sabah Savaşçısı',
        'Güne hareket, enerji ve düzenle başlamak için kısa bir sabah rutini.',
        'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=400',
        30,
        TRUE,
        1
      FROM template_categories tc
      WHERE tc.name = 'Fitness'
        AND NOT EXISTS (SELECT 1 FROM habit_templates WHERE title = 'Sabah Savaşçısı');

      INSERT INTO habit_templates
        (category_id, title, description, image_url, estimated_duration_days, is_featured, display_order)
      SELECT
        tc.id,
        'Derin Odaklanma',
        'Dikkatini korumak ve günü planlı ilerletmek için üretkenlik rutini.',
        'https://images.unsplash.com/photo-1484480974693-6ca0a78fb36b?w=400',
        30,
        TRUE,
        1
      FROM template_categories tc
      WHERE tc.name = 'Productivity'
        AND NOT EXISTS (SELECT 1 FROM habit_templates WHERE title = 'Derin Odaklanma');

      INSERT INTO habit_templates
        (category_id, title, description, image_url, estimated_duration_days, is_featured, display_order)
      SELECT
        tc.id,
        'Huzurlu Akşamlar',
        'Günü sakin kapatmak, zihni boşaltmak ve uykuya hazırlanmak için akşam rutini.',
        'https://images.unsplash.com/photo-1506126613408-eca07ce68773?w=400',
        30,
        TRUE,
        1
      FROM template_categories tc
      WHERE tc.name = 'Wellness'
        AND NOT EXISTS (SELECT 1 FROM habit_templates WHERE title = 'Huzurlu Akşamlar');

      INSERT INTO habit_templates
        (category_id, title, description, image_url, estimated_duration_days, is_featured, display_order)
      SELECT
        tc.id,
        'Güçlü Beden',
        'Daha aktif kalmak ve temel sağlık alışkanlıklarını düzenli takip etmek için plan.',
        'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400',
        30,
        FALSE,
        2
      FROM template_categories tc
      WHERE tc.name = 'Fitness'
        AND NOT EXISTS (SELECT 1 FROM habit_templates WHERE title = 'Güçlü Beden');

      INSERT INTO habit_templates
        (category_id, title, description, image_url, estimated_duration_days, is_featured, display_order)
      SELECT
        tc.id,
        'Okuma Ritüeli',
        'Düzenli okuma, not alma ve öğrenmeyi kalıcı hale getirme rutini.',
        'https://images.unsplash.com/photo-1481627834876-b7833e8f5570?w=400',
        30,
        FALSE,
        1
      FROM template_categories tc
      WHERE tc.name = 'Learning'
        AND NOT EXISTS (SELECT 1 FROM habit_templates WHERE title = 'Okuma Ritüeli');

      INSERT INTO habit_templates
        (category_id, title, description, image_url, estimated_duration_days, is_featured, display_order)
      SELECT
        tc.id,
        'Su Dengesi',
        'Gün boyunca yeterli su içmeyi ve bedeni destekleyen küçük sağlık adımlarını takip et.',
        'https://images.unsplash.com/photo-1548839140-29a749e1cf4d?w=400',
        21,
        FALSE,
        2
      FROM template_categories tc
      WHERE tc.name = 'Wellness'
        AND NOT EXISTS (SELECT 1 FROM habit_templates WHERE title = 'Su Dengesi');

      INSERT INTO habit_templates
        (category_id, title, description, image_url, estimated_duration_days, is_featured, display_order)
      SELECT
        tc.id,
        'Dijital Detoks',
        'Ekran kullanımını azaltmak ve zihinsel alan açmak için sakin bir rutin.',
        'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=400',
        14,
        FALSE,
        3
      FROM template_categories tc
      WHERE tc.name = 'Productivity'
        AND NOT EXISTS (SELECT 1 FROM habit_templates WHERE title = 'Dijital Detoks');

      INSERT INTO habit_templates
        (category_id, title, description, image_url, estimated_duration_days, is_featured, display_order)
      SELECT
        tc.id,
        'Uyku Kalitesi',
        'Daha düzenli uykuya hazırlanmak için akşam odaklı alışkanlık seti.',
        'https://images.unsplash.com/photo-1541781774459-bb2af2f05b55?w=400',
        21,
        FALSE,
        3
      FROM template_categories tc
      WHERE tc.name = 'Wellness'
        AND NOT EXISTS (SELECT 1 FROM habit_templates WHERE title = 'Uyku Kalitesi');

      INSERT INTO habit_templates
        (category_id, title, description, image_url, estimated_duration_days, is_featured, display_order)
      SELECT
        tc.id,
        'Dil Öğrenme',
        'Her gün kısa ama düzenli pratikle yeni bir dili canlı tut.',
        'https://images.unsplash.com/photo-1434030216411-0b793f4b4173?w=400',
        30,
        FALSE,
        2
      FROM template_categories tc
      WHERE tc.name = 'Learning'
        AND NOT EXISTS (SELECT 1 FROM habit_templates WHERE title = 'Dil Öğrenme');

      INSERT INTO habit_templates
        (category_id, title, description, image_url, estimated_duration_days, is_featured, display_order)
      SELECT
        tc.id,
        'Ev Düzeni',
        'Yaşam alanını küçük günlük adımlarla daha düzenli tut.',
        'https://images.unsplash.com/photo-1524758631624-e2822e304c36?w=400',
        14,
        FALSE,
        4
      FROM template_categories tc
      WHERE tc.name = 'Productivity'
        AND NOT EXISTS (SELECT 1 FROM habit_templates WHERE title = 'Ev Düzeni');

      INSERT INTO habit_templates
        (category_id, title, description, image_url, estimated_duration_days, is_featured, display_order)
      SELECT
        tc.id,
        'Finans Farkındalığı',
        'Harcamaları fark etmek ve küçük finans kontrolleri yapmak için başlangıç rutini.',
        'https://images.unsplash.com/photo-1554224155-6726b3ff858f?w=400',
        30,
        FALSE,
        5
      FROM template_categories tc
      WHERE tc.name = 'Productivity'
        AND NOT EXISTS (SELECT 1 FROM habit_templates WHERE title = 'Finans Farkındalığı');

      INSERT INTO template_habits
        (template_id, name, description, period, frequency_type, days, target_value, goal_unit, display_order)
      SELECT ht.id, habit.name, habit.description, habit.period, 'weekly', habit.days, habit.target_value, habit.goal_unit, habit.display_order
      FROM habit_templates ht
      CROSS JOIN (
        VALUES
          ('7 AM Uyanış', 'Güne aynı saatte başlayarak ritmini sabitle.', 'morning', ARRAY[1,2,3,4,5], NULL::integer, NULL::varchar, 1),
          ('10 dk Esneme', 'Kısa bir esneme ile bedeni uyandır.', 'morning', ARRAY[1,2,3,4,5,6,7], 10, 'minute', 2),
          ('20 dk Koşu', 'Hafif tempolu koşu veya yürüyüş yap.', 'morning', ARRAY[1,3,5], 20, 'minute', 3),
          ('Soğuk Duş', 'Duşunu kısa ve canlandırıcı bir rutinle bitir.', 'morning', ARRAY[1,2,3,4,5], NULL::integer, NULL::varchar, 4),
          ('Sağlıklı Kahvaltı', 'Güne dengeli bir kahvaltı ile başla.', 'morning', ARRAY[1,2,3,4,5,6,7], NULL::integer, NULL::varchar, 5)
      ) AS habit(name, description, period, days, target_value, goal_unit, display_order)
      WHERE ht.title = 'Sabah Savaşçısı'
        AND NOT EXISTS (
          SELECT 1 FROM template_habits th
          WHERE th.template_id = ht.id AND th.name = habit.name
        );

      INSERT INTO template_habits
        (template_id, name, description, period, frequency_type, days, target_value, goal_unit, display_order)
      SELECT ht.id, habit.name, habit.description, habit.period, 'weekly', habit.days, habit.target_value, habit.goal_unit, habit.display_order
      FROM habit_templates ht
      CROSS JOIN (
        VALUES
          ('Günü Planla', 'Başlamadan önce günün önceliklerini belirle.', 'morning', ARRAY[1,2,3,4,5], NULL::integer, NULL::varchar, 1),
          ('90 dk Blok Çalışma', 'Tek bir işe bölünmeden odaklan.', 'all', ARRAY[1,2,3,4,5], 90, 'minute', 2),
          ('Öğleye Kadar Telefon Yok', 'Sabah saatlerinde dikkatini koru.', 'morning', ARRAY[1,2,3,4,5], NULL::integer, NULL::varchar, 3),
          ('Gün Sonu Değerlendirmesi', 'Günün sonunda neyin iyi gittiğini yaz.', 'evening', ARRAY[1,2,3,4,5], NULL::integer, NULL::varchar, 4)
      ) AS habit(name, description, period, days, target_value, goal_unit, display_order)
      WHERE ht.title = 'Derin Odaklanma'
        AND NOT EXISTS (
          SELECT 1 FROM template_habits th
          WHERE th.template_id = ht.id AND th.name = habit.name
        );

      INSERT INTO template_habits
        (template_id, name, description, period, frequency_type, days, target_value, goal_unit, display_order)
      SELECT ht.id, habit.name, habit.description, habit.period, 'weekly', habit.days, habit.target_value, habit.goal_unit, habit.display_order
      FROM habit_templates ht
      CROSS JOIN (
        VALUES
          ('10 dk Meditasyon', 'Nefesine odaklanarak zihnini yavaşlat.', 'evening', ARRAY[1,2,3,4,5,6,7], 10, 'minute', 1),
          ('Şükran Günlüğü', 'Bugün iyi gelen üç şeyi yaz.', 'evening', ARRAY[1,2,3,4,5,6,7], NULL::integer, NULL::varchar, 2),
          ('Ekransız Son Saat', 'Uyumadan önce ekranları kapat.', 'evening', ARRAY[1,2,3,4,5,6,7], NULL::integer, NULL::varchar, 3)
      ) AS habit(name, description, period, days, target_value, goal_unit, display_order)
      WHERE ht.title = 'Huzurlu Akşamlar'
        AND NOT EXISTS (
          SELECT 1 FROM template_habits th
          WHERE th.template_id = ht.id AND th.name = habit.name
        );

      INSERT INTO template_habits
        (template_id, name, description, period, frequency_type, days, target_value, goal_unit, display_order)
      SELECT ht.id, habit.name, habit.description, habit.period, 'weekly', habit.days, habit.target_value, habit.goal_unit, habit.display_order
      FROM habit_templates ht
      CROSS JOIN (
        VALUES
          ('Güç Antrenmanı', 'Haftada üç gün temel kuvvet çalışması yap.', 'all', ARRAY[1,3,5], NULL::integer, NULL::varchar, 1),
          ('Günlük Adım Hedefi', 'Gün içinde hareket etmeyi takip et.', 'all', ARRAY[1,2,3,4,5,6,7], 8000, 'step', 2),
          ('Protein Takibi', 'Her gün protein hedefini takip et.', 'all', ARRAY[1,2,3,4,5,6,7], NULL::integer, NULL::varchar, 3),
          ('8 Saat Uyku', 'Uyku düzenini korumaya çalış.', 'evening', ARRAY[1,2,3,4,5,6,7], 8, 'hour', 4)
      ) AS habit(name, description, period, days, target_value, goal_unit, display_order)
      WHERE ht.title = 'Güçlü Beden'
        AND NOT EXISTS (
          SELECT 1 FROM template_habits th
          WHERE th.template_id = ht.id AND th.name = habit.name
        );

      INSERT INTO template_habits
        (template_id, name, description, period, frequency_type, days, target_value, goal_unit, display_order)
      SELECT ht.id, habit.name, habit.description, habit.period, 'weekly', habit.days, habit.target_value, habit.goal_unit, habit.display_order
      FROM habit_templates ht
      CROSS JOIN (
        VALUES
          ('30 Sayfa Kitap Oku', 'Her gün düzenli okuma yap.', 'all', ARRAY[1,2,3,4,5,6,7], 30, 'count', 1),
          ('Notlar Al', 'Önemli fikirleri kısa notlara dönüştür.', 'all', ARRAY[1,2,3,4,5,6,7], NULL::integer, NULL::varchar, 2),
          ('Haftalık Özet Çıkar', 'Hafta sonunda öğrendiklerini toparla.', 'evening', ARRAY[7], NULL::integer, NULL::varchar, 3)
      ) AS habit(name, description, period, days, target_value, goal_unit, display_order)
      WHERE ht.title = 'Okuma Ritüeli'
        AND NOT EXISTS (
          SELECT 1 FROM template_habits th
          WHERE th.template_id = ht.id AND th.name = habit.name
        );

      INSERT INTO template_habits
        (template_id, name, description, period, frequency_type, days, target_value, goal_unit, display_order)
      SELECT ht.id, habit.name, habit.description, habit.period, 'weekly', habit.days, habit.target_value, habit.goal_unit, habit.display_order
      FROM habit_templates ht
      CROSS JOIN (
        VALUES
          ('2 Litre Su İç', 'Gün içinde su tüketimini takip et.', 'all', ARRAY[1,2,3,4,5,6,7], 2, 'liter', 1),
          ('Sabah Bir Bardak Su', 'Güne su içerek başla.', 'morning', ARRAY[1,2,3,4,5,6,7], NULL::integer, NULL::varchar, 2),
          ('Kafeini Sınırla', 'Gün içinde kahve/çay tüketimini fark et.', 'all', ARRAY[1,2,3,4,5,6,7], NULL::integer, NULL::varchar, 3)
      ) AS habit(name, description, period, days, target_value, goal_unit, display_order)
      WHERE ht.title = 'Su Dengesi'
        AND NOT EXISTS (
          SELECT 1 FROM template_habits th
          WHERE th.template_id = ht.id AND th.name = habit.name
        );

      INSERT INTO template_habits
        (template_id, name, description, period, frequency_type, days, target_value, goal_unit, display_order)
      SELECT ht.id, habit.name, habit.description, habit.period, 'weekly', habit.days, habit.target_value, habit.goal_unit, habit.display_order
      FROM habit_templates ht
      CROSS JOIN (
        VALUES
          ('Sosyal Medya Limiti', 'Sosyal medya kullanımını bilinçli sınırla.', 'all', ARRAY[1,2,3,4,5,6,7], 30, 'minute', 1),
          ('Bildirimleri Kapat', 'Odaklanma bloklarında dikkat dağıtıcı bildirimleri kapat.', 'all', ARRAY[1,2,3,4,5], NULL::integer, NULL::varchar, 2),
          ('Ekransız Yemek', 'En az bir öğünü ekransız geçir.', 'all', ARRAY[1,2,3,4,5,6,7], NULL::integer, NULL::varchar, 3)
      ) AS habit(name, description, period, days, target_value, goal_unit, display_order)
      WHERE ht.title = 'Dijital Detoks'
        AND NOT EXISTS (
          SELECT 1 FROM template_habits th
          WHERE th.template_id = ht.id AND th.name = habit.name
        );

      INSERT INTO template_habits
        (template_id, name, description, period, frequency_type, days, target_value, goal_unit, display_order)
      SELECT ht.id, habit.name, habit.description, habit.period, 'weekly', habit.days, habit.target_value, habit.goal_unit, habit.display_order
      FROM habit_templates ht
      CROSS JOIN (
        VALUES
          ('Aynı Saatte Yat', 'Uyku saatini düzenli tutmaya çalış.', 'evening', ARRAY[1,2,3,4,5,6,7], NULL::integer, NULL::varchar, 1),
          ('Odayı Hazırla', 'Uyumadan önce ortamı sakinleştir.', 'evening', ARRAY[1,2,3,4,5,6,7], NULL::integer, NULL::varchar, 2),
          ('Kafein Kesme Saati', 'Akşam saatlerinde kafeinden uzak dur.', 'evening', ARRAY[1,2,3,4,5,6,7], NULL::integer, NULL::varchar, 3),
          ('8 Saat Uyku Hedefi', 'Uyku süreni takip et.', 'evening', ARRAY[1,2,3,4,5,6,7], 8, 'hour', 4)
      ) AS habit(name, description, period, days, target_value, goal_unit, display_order)
      WHERE ht.title = 'Uyku Kalitesi'
        AND NOT EXISTS (
          SELECT 1 FROM template_habits th
          WHERE th.template_id = ht.id AND th.name = habit.name
        );

      INSERT INTO template_habits
        (template_id, name, description, period, frequency_type, days, target_value, goal_unit, display_order)
      SELECT ht.id, habit.name, habit.description, habit.period, 'weekly', habit.days, habit.target_value, habit.goal_unit, habit.display_order
      FROM habit_templates ht
      CROSS JOIN (
        VALUES
          ('15 dk Kelime Çalış', 'Yeni kelimeleri kısa tekrarlarla çalış.', 'all', ARRAY[1,2,3,4,5,6,7], 15, 'minute', 1),
          ('Dinleme Pratiği', 'Kısa bir podcast/video ile kulağını alıştır.', 'all', ARRAY[1,2,3,4,5], 10, 'minute', 2),
          ('3 Cümle Yaz', 'Öğrendiğin dilde üç basit cümle kur.', 'evening', ARRAY[1,2,3,4,5,6,7], 3, 'count', 3)
      ) AS habit(name, description, period, days, target_value, goal_unit, display_order)
      WHERE ht.title = 'Dil Öğrenme'
        AND NOT EXISTS (
          SELECT 1 FROM template_habits th
          WHERE th.template_id = ht.id AND th.name = habit.name
        );

      INSERT INTO template_habits
        (template_id, name, description, period, frequency_type, days, target_value, goal_unit, display_order)
      SELECT ht.id, habit.name, habit.description, habit.period, 'weekly', habit.days, habit.target_value, habit.goal_unit, habit.display_order
      FROM habit_templates ht
      CROSS JOIN (
        VALUES
          ('10 dk Toparlama', 'Günün sonunda kısa bir alan toparlama yap.', 'evening', ARRAY[1,2,3,4,5,6,7], 10, 'minute', 1),
          ('Masayı Temizle', 'Çalışma alanını düzenli bırak.', 'evening', ARRAY[1,2,3,4,5], NULL::integer, NULL::varchar, 2),
          ('Çamaşır Kontrolü', 'Biriken çamaşırları kontrol et.', 'all', ARRAY[2,5], NULL::integer, NULL::varchar, 3)
      ) AS habit(name, description, period, days, target_value, goal_unit, display_order)
      WHERE ht.title = 'Ev Düzeni'
        AND NOT EXISTS (
          SELECT 1 FROM template_habits th
          WHERE th.template_id = ht.id AND th.name = habit.name
        );

      INSERT INTO template_habits
        (template_id, name, description, period, frequency_type, days, target_value, goal_unit, display_order)
      SELECT ht.id, habit.name, habit.description, habit.period, 'weekly', habit.days, habit.target_value, habit.goal_unit, habit.display_order
      FROM habit_templates ht
      CROSS JOIN (
        VALUES
          ('Harcama Kaydı', 'Günün harcamalarını kısa kısa not et.', 'evening', ARRAY[1,2,3,4,5,6,7], NULL::integer, NULL::varchar, 1),
          ('Bütçe Kontrolü', 'Kalan haftalık bütçeni gözden geçir.', 'evening', ARRAY[1,4], NULL::integer, NULL::varchar, 2),
          ('Gereksiz Alımı Ertele', 'Ani alışverişleri bir gün beklet.', 'all', ARRAY[1,2,3,4,5,6,7], NULL::integer, NULL::varchar, 3)
      ) AS habit(name, description, period, days, target_value, goal_unit, display_order)
      WHERE ht.title = 'Finans Farkındalığı'
        AND NOT EXISTS (
          SELECT 1 FROM template_habits th
          WHERE th.template_id = ht.id AND th.name = habit.name
        );
    `);
  }

  return schemaReadyPromise;
};

const getHabitTemplates = async (req, res) => {
  try {
    await ensureHabitTemplateSchema();

    const result = await pool.query(`
      SELECT
        ht.id,
        ht.title,
        ht.description,
        ht.image_url,
        ht.is_featured,
        ht.display_order,
        tc.name AS category,
        tc.emoji AS category_emoji,
        EXISTS (
          SELECT 1
          FROM user_template_additions uta
          WHERE uta.user_id = $1
            AND uta.template_id = ht.id::text
        ) AS is_added,
        COUNT(th.id)::int AS habit_count,
        COALESCE(
          json_agg(
            json_build_object(
              'id', th.id,
              'name', th.name,
              'description', th.description,
              'period', th.period,
              'frequency_type', th.frequency_type,
              'days', th.days,
              'target_value', th.target_value,
              'goal_unit', th.goal_unit,
              'display_order', th.display_order
            )
            ORDER BY th.display_order
          ) FILTER (WHERE th.id IS NOT NULL),
          '[]'
        ) AS habits
      FROM habit_templates ht
      JOIN template_categories tc
        ON ht.category_id = tc.id
      LEFT JOIN template_habits th
        ON ht.id = th.template_id
      GROUP BY
        ht.id,
        ht.title,
        ht.description,
        ht.image_url,
        ht.is_featured,
        ht.display_order,
        tc.name,
        tc.emoji,
        tc.display_order
      ORDER BY
        ht.is_featured DESC,
        tc.display_order ASC,
        ht.display_order ASC
    `, [req.user.userId]);

    const categorySet = new Set();

    for (const template of result.rows) {
      categorySet.add(template.category);
    }

    return res.status(200).json({
      categories: Array.from(categorySet),
      templates: result.rows,
    });
  } catch (err) {
    console.error("GET HABIT TEMPLATES ERROR:", err);

    return res.status(500).json({
      message: "Habit templates could not be loaded",
    });
  }
};

const addHabitTemplate = async (req, res) => {
  await ensureHabitTemplateSchema();

  const client = await pool.connect();

  try {
    const userId = req.user.userId;
    const templateId = req.params.id;

    if (!templateId || typeof templateId !== "string") {
      return res.status(400).json({
        message: "Invalid template id",
      });
    }

    await client.query("BEGIN");

    const templateResult = await client.query(
      `
      SELECT id, title
      FROM habit_templates
      WHERE id = $1
      `,
      [templateId]
    );

    if (templateResult.rows.length === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({
        message: "Habit template not found",
      });
    }

    const additionResult = await client.query(
      `
      INSERT INTO user_template_additions
        (user_id, template_id)
      VALUES
        ($1, $2)
      ON CONFLICT (user_id, template_id)
      DO NOTHING
      RETURNING id
      `,
      [userId, templateId]
    );

    if (additionResult.rows.length === 0) {
      await client.query("ROLLBACK");
      return res.status(409).json({
        message: "Template already added",
        alreadyAdded: true,
        addedCount: 0,
      });
    }

    const habitsResult = await client.query(
      `
      SELECT
        name,
        description,
        period,
        frequency_type,
        days,
        target_value,
        goal_unit
      FROM template_habits
      WHERE template_id = $1
      ORDER BY display_order ASC
      `,
      [templateId]
    );

    if (habitsResult.rows.length === 0) {
      await client.query("ROLLBACK");
      return res.status(400).json({
        message: "This template has no habits",
      });
    }

    const createdHabitIds = [];

    for (const habit of habitsResult.rows) {
      const habitResult = await client.query(
        `
        INSERT INTO habits
          (
            user_id,
            name,
            description,
            frequency_type,
            period,
            target_value,
            goal_unit,
            source_template_id,
            source_template_title
          )
        VALUES
          ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        RETURNING id
        `,
        [
          userId,
          habit.name,
          habit.description || null,
          habit.frequency_type,
          habit.period,
          habit.target_value,
          habit.goal_unit,
          templateId,
          templateResult.rows[0].title,
        ]
      );

      const habitId = habitResult.rows[0].id;
      createdHabitIds.push(habitId);

      const days = Array.isArray(habit.days) ? habit.days : [];

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
    }

    await client.query("COMMIT");

    return res.status(201).json({
      message: "Template added successfully",
      addedCount: createdHabitIds.length,
      habitIds: createdHabitIds,
    });
  } catch (err) {
    await client.query("ROLLBACK");

    console.error("ADD HABIT TEMPLATE ERROR:", err);

    return res.status(500).json({
      message: "Habit template could not be added",
    });
  } finally {
    client.release();
  }
};

const deleteHabitTemplateGroup = async (req, res) => {
  await ensureHabitTemplateSchema();

  const templateId = req.params.id;

  if (!templateId || typeof templateId !== "string") {
    return res.status(400).json({
      message: "Invalid template id",
    });
  }

  const client = await pool.connect();

  try {
    const userId = req.user.userId;

    await client.query("BEGIN");

    const templateResult = await client.query(
      `
      SELECT id
      FROM habit_templates
      WHERE id = $1
      `,
      [templateId]
    );

    if (templateResult.rows.length === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({
        message: "Habit template not found",
      });
    }

    const templateGroupCondition = `
      h.user_id = $1
      AND (
        h.source_template_id = $2
        OR (
          h.source_template_id IS NULL
          AND EXISTS (
            SELECT 1
            FROM user_template_additions uta
            JOIN template_habits th
              ON th.template_id::text = uta.template_id
            WHERE uta.user_id = $1
              AND uta.template_id = $2
              AND th.name = h.name
          )
        )
      )
    `;

    const habitResult = await client.query(
      `
      SELECT id
      FROM habits h
      WHERE ${templateGroupCondition}
      `,
      [userId, templateId]
    );

    if (habitResult.rows.length === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({
        message: "Template group not found",
      });
    }

    const habitIds = habitResult.rows.map((habit) => habit.id);

    await client.query(
      `
      DELETE FROM habit_logs hl
      USING habits h
      WHERE hl.habit_id = h.id
        AND hl.user_id = $1
        AND ${templateGroupCondition}
      `,
      [userId, templateId]
    );

    await client.query(
      `
      DELETE FROM habit_days hd
      USING habits h
      WHERE hd.habit_id = h.id
        AND ${templateGroupCondition}
      `,
      [userId, templateId]
    );

    await client.query(
      `
      DELETE FROM habits h
      WHERE ${templateGroupCondition}
      `,
      [userId, templateId]
    );

    await client.query(
      `
      DELETE FROM user_template_additions
      WHERE user_id = $1
        AND template_id = $2
      `,
      [userId, templateId]
    );

    await client.query("COMMIT");

    return res.status(200).json({
      message: "Template group deleted successfully",
      deletedCount: habitIds.length,
    });
  } catch (err) {
    await client.query("ROLLBACK");

    console.error("DELETE HABIT TEMPLATE GROUP ERROR:", err);

    return res.status(500).json({
      message: "Habit template group could not be deleted",
    });
  } finally {
    client.release();
  }
};

module.exports = {
  getHabitTemplates,
  addHabitTemplate,
  deleteHabitTemplateGroup,
};
