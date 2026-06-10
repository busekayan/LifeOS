exports.up = (pgm) => {
  pgm.createTable("users", {
    id: "id",
    email: {
      type: "varchar(255)",
      notNull: true,
      unique: true,
    },
    first_name: {
      type: "varchar(100)",
      notNull: true,
    },
    last_name: {
      type: "varchar(100)",
      notNull: true,
    },
    password_hash: {
      type: "varchar(255)",
      notNull: true,
    },
    created_at: {
      type: "timestamp",
      notNull: true,
      default: pgm.func("current_timestamp"),
    },
  });
};

exports.down = (pgm) => {
  pgm.dropTable("users");
};
