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
              u_id INTEGER NOT NULL, 
              r_id INTEGER NOT NULL, 
              reason TEXT, 
              start_time TEXT NOT NULL, 
              end_time TEXT NOT NULL, 
              booking_category INTEGER,
              PRIMARY KEY (u_id, r_id), 
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
              FOREIGN KEY (c_id) REFERENCES room_categories(id) 
                ON DELETE CASCADE)')
end

def populate_tables(db)
  db.execute('INSERT INTO rooms (name) VALUES ("204")')
  db.execute('INSERT INTO rooms (name) VALUES ("318")')
  db.execute('INSERT INTO rooms (name) VALUES ("316")')
  db.execute('INSERT INTO rooms (name) VALUES ("425")')

  db.execute('INSERT INTO room_category (category) VALUES ("Klassrum")')
  db.execute('INSERT INTO room_category (category) VALUES ("Kemisal")')
  db.execute('INSERT INTO room_category (category) VALUES ("Grupprum")')

  db.execute('INSERT INTO booking_category (category) VALUES ("Lektion")')
  db.execute('INSERT INTO booking_category (category) VALUES ("Klubbverksamhet")')

end


seed!(db)