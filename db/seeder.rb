require 'sqlite3'

db = SQLite3::Database.new("databas.db")


def seed!(db)
  puts "Using db file: db/todos.db"
  puts "🧹 Dropping old tables..."
  drop_tables(db)
  puts "🧱 Creating tables..."
  create_tables(db)
  puts "🍎 Populating tables..."
  populate_tables(db)
  puts "✅ Done seeding the database!"
end

def drop_tables(db)
  db.execute('DROP TABLE IF EXISTS users')
  db.execute('DROP TABLE IF EXISTS rooms')
  db.execute('DROP TABLE IF EXISTS room_category')
  db.execute('DROP TABLE IF EXISTS booking_category')
  db.execute('DROP TABLE IF EXISTS user_room_rel')
  db.execute('DROP TABLE IF EXISTS room_category_rel')
end

# FIXA KORREKTA RELATIONSTABELLER

def create_tables(db)
  db.execute('CREATE TABLE users (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL, 
              pwd_digest TEXT NOT NULL,
              teacher BOOL)')

  db.execute('CREATE TABLE rooms (
              id INTEGER PRIMARY KEY AUTOINCREMENT, 
              name TEXT NOT NULL)')

  db.execute('CREATE TABLE room_category (
              id INTEGER PRIMARY KEY AUTOINCREMENT, 
              category TEXT NOT NULL)')

  db.execute('CREATE TABLE booking_category (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              category TEXT NOT NULL)')

  db.execute('CREATE TABLE user_room_rel (
              booking_id INTEGER PRIMARY KEY AUTOINCREMENT,
              u_id INTEGER NOT NULL, 
              r_id INTEGER NOT NULL, 
              reason TEXT, 
              start_time TEXT NOT NULL, 
              end_time TEXT NOT NULL, 
              booking_category INTEGER,
              FOREIGN KEY (u_id) REFERENCES users(id)
                ON DELETE CASCADE,
              FOREIGN KEY (r_id) REFERENCES rooms(id)
                ON DELETE CASCADE,
              FOREIGN KEY (booking_category) REFERENCES booking_category(id))')

  db.execute('CREATE TABLE room_category_rel (
              r_id INTEGER NOT NULL, 
              c_id INTEGER NOT NULL, 
              PRIMARY KEY (r_id, c_id), 
              FOREIGN KEY (r_id) REFERENCES rooms(id) 
                ON DELETE CASCADE, 
              FOREIGN KEY (c_id) REFERENCES room_category(id) 
                ON DELETE CASCADE)')
end

def populate_tables(db)
  db.execute('INSERT INTO rooms (name) VALUES ("Tempel of Silence")')
  db.execute('INSERT INTO rooms (name) VALUES ("204")')
  db.execute('INSERT INTO rooms (name) VALUES ("213")')
  db.execute('INSERT INTO rooms (name) VALUES ("215")')
  db.execute('INSERT INTO rooms (name) VALUES ("306")')
  db.execute('INSERT INTO rooms (name) VALUES ("314")')
  db.execute('INSERT INTO rooms (name) VALUES ("316")')
  db.execute('INSERT INTO rooms (name) VALUES ("318")')
  db.execute('INSERT INTO rooms (name) VALUES ("325")')
  db.execute('INSERT INTO rooms (name) VALUES ("406")')
  db.execute('INSERT INTO rooms (name) VALUES ("407: Grupprum")')
  db.execute('INSERT INTO rooms (name) VALUES ("410")')
  db.execute('INSERT INTO rooms (name) VALUES ("421")')
  db.execute('INSERT INTO rooms (name) VALUES ("426")')
  db.execute('INSERT INTO rooms (name) VALUES ("Fotostudio")')
  db.execute('INSERT INTO rooms (name) VALUES ("IT-Prepprum")')
  db.execute('INSERT INTO rooms (name) VALUES ("K1")')
  db.execute('INSERT INTO rooms (name) VALUES ("K2")')
  db.execute('INSERT INTO rooms (name) VALUES ("K3: Kårrum")')
  db.execute('INSERT INTO rooms (name) VALUES ("K4: TE4")')
  db.execute('INSERT INTO rooms (name) VALUES ("Kemilabb")')
  db.execute('INSERT INTO rooms (name) VALUES ("Konferansrum")')
  db.execute('INSERT INTO rooms (name) VALUES ("Lanlab")')
  db.execute('INSERT INTO rooms (name) VALUES ("Musikrum")')
  db.execute('INSERT INTO rooms (name) VALUES ("Musikstudio")')

  db.execute('INSERT INTO room_category (category) VALUES ("Klassrum")')
  db.execute('INSERT INTO room_category (category) VALUES ("Kemisal")')
  db.execute('INSERT INTO room_category (category) VALUES ("Grupprum")')
  db.execute('INSERT INTO room_category (category) VALUES ("Annat")')

  db.execute('INSERT INTO booking_category (category) VALUES ("Lektion")')
  db.execute('INSERT INTO booking_category (category) VALUES ("Klubbverksamhet")')
  
  # Bokningar
  db.execute('INSERT INTO user_room_rel (u_id, r_id, reason, start_time, end_time, booking_category) VALUES (1, 1, "Kemilektion", "2022-10-18-15-00-00", "2022-10-18-16-00-00", 1)')
  db.execute('INSERT INTO user_room_rel (u_id, r_id, reason, start_time, end_time, booking_category) VALUES (2, 2, "Filmklubb-möte", "2023-01-20-15-00-00", "2023-01-20-16-00-00", 2)')

  db.execute('INSERT INTO room_category_rel (r_id, c_id) VALUES (1, 3)')
  db.execute('INSERT INTO room_category_rel (r_id, c_id) VALUES (2, 1)')
  db.execute('INSERT INTO room_category_rel (r_id, c_id) VALUES (3, 1)')
  db.execute('INSERT INTO room_category_rel (r_id, c_id) VALUES (4, 1)')
  db.execute('INSERT INTO room_category_rel (r_id, c_id) VALUES (5, 1)')
  db.execute('INSERT INTO room_category_rel (r_id, c_id) VALUES (6, 1)')
  db.execute('INSERT INTO room_category_rel (r_id, c_id) VALUES (7, 1)')
  db.execute('INSERT INTO room_category_rel (r_id, c_id) VALUES (8, 1)')
  db.execute('INSERT INTO room_category_rel (r_id, c_id) VALUES (9, 1)')
  db.execute('INSERT INTO room_category_rel (r_id, c_id) VALUES (10, 1)')
  db.execute('INSERT INTO room_category_rel (r_id, c_id) VALUES (11, 3)')
  db.execute('INSERT INTO room_category_rel (r_id, c_id) VALUES (11, 1)')
  db.execute('INSERT INTO room_category_rel (r_id, c_id) VALUES (12, 1)')
  db.execute('INSERT INTO room_category_rel (r_id, c_id) VALUES (13, 1)')
  db.execute('INSERT INTO room_category_rel (r_id, c_id) VALUES (14, 1)')
  db.execute('INSERT INTO room_category_rel (r_id, c_id) VALUES (15, 4)')
  db.execute('INSERT INTO room_category_rel (r_id, c_id) VALUES (16, 4)')
  db.execute('INSERT INTO room_category_rel (r_id, c_id) VALUES (17, 1)')
  db.execute('INSERT INTO room_category_rel (r_id, c_id) VALUES (18, 1)')
  db.execute('INSERT INTO room_category_rel (r_id, c_id) VALUES (19, 1)')
  db.execute('INSERT INTO room_category_rel (r_id, c_id) VALUES (20, 1)')
  db.execute('INSERT INTO room_category_rel (r_id, c_id) VALUES (21, 2)')
  db.execute('INSERT INTO room_category_rel (r_id, c_id) VALUES (22, 3)')
  db.execute('INSERT INTO room_category_rel (r_id, c_id) VALUES (23, 1)')
  db.execute('INSERT INTO room_category_rel (r_id, c_id) VALUES (24, 4)')
  db.execute('INSERT INTO room_category_rel (r_id, c_id) VALUES (25, 4)')

end


seed!(db)