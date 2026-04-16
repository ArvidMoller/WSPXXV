require 'sqlite3'

# The Model module provides all database access methods for the booking application.
# It is intended to be included in the Sinatra application and interacts with an
# SQLite3 database containing users, rooms, bookings, and booking categories.
module Model
  # Opens a connection to the specified SQLite3 database and configures it to
  # return results as hashes.
  #
  # @param name [String] the name of the database file (without path or extension)
  # @return [SQLite3::Database] an open database connection with hash-keyed results
  def load_db(name)
    db = SQLite3::Database.new("db/#{name}.db")
    db.results_as_hash = true
    db.execute("PRAGMA foreign_keys = ON")

    return db
  end


  # Retrieves all bookings whose associated room name matches the given search query.
  # Joins the user_room_rel, rooms, users, and booking_category tables to return
  # a complete view of each booking.
  #
  # @param db [SQLite3::Database] an open database connection
  # @param query [String] a search string matched against room names using SQL LIKE;
  #   pass an empty string to return all bookings
  # @return [Array<Hash>] an array of booking hashes with keys: booking_id, room_name,
  #   user_name, reason, start_time, end_time, category
  def get_bookings(db, query)
    bookings = db.execute("SELECT user_room_rel.booking_id, rooms.name AS room_name, users.name AS user_name, user_room_rel.reason, user_room_rel.start_time, user_room_rel.end_time, booking_category.category FROM user_room_rel INNER JOIN rooms ON user_room_rel.r_id = rooms.id INNER JOIN users ON user_room_rel.u_id = users.id INNER JOIN booking_category ON user_room_rel.booking_category = booking_category.id  WHERE rooms.name LIKE ?", "%#{query}%")

    return bookings
  end


  # Retrieves a single booking by its ID.
  # Joins the user_room_rel, rooms, users, and booking_category tables to provide
  # complete booking information.
  #
  # @param db [SQLite3::Database] an open database connection
  # @param id [Integer] the booking ID to look up
  # @return [Hash, nil] a booking hash with keys: booking_id, room_name, user_name,
  #   reason, start_time, end_time, category; or nil if no matching booking is found
  def get_booking_on_id(db, id)
    booking = db.execute("SELECT user_room_rel.booking_id, rooms.name AS room_name, users.name AS user_name, user_room_rel.reason, user_room_rel.start_time, user_room_rel.end_time, booking_category.category FROM user_room_rel INNER JOIN rooms ON user_room_rel.r_id = rooms.id INNER JOIN users ON user_room_rel.u_id = users.id INNER JOIN booking_category ON user_room_rel.booking_category = booking_category.id WHERE user_room_rel.booking_id = ?", id).first
    return booking
  end


  # Retrieves all bookings associated with a specific room.
  # Returns raw rows from user_room_rel without joining other tables.
  #
  # @param db [SQLite3::Database] an open database connection
  # @param room_id [Integer] the ID of the room to query bookings for
  # @return [Array<Hash>] an array of raw user_room_rel row hashes for the given room
  def get_booking_on_room_id(db, room_id)
    bookings = db.execute("SELECT * FROM user_room_rel WHERE r_id = ?", room_id)
    return bookings
  end


  # Inserts a new booking record into the user_room_rel table.
  #
  # @param db [SQLite3::Database] an open database connection
  # @param user_id [Integer] the ID of the user making the booking
  # @param room_id [Integer] the ID of the room being booked
  # @param reason [String] the reason or description for the booking
  # @param start_time [String] the booking start time in "YYYY-MM-DD HH:MM:SS" format
  # @param end_time [String] the booking end time in "YYYY-MM-DD HH:MM:SS" format
  # @param booking_category [Integer] the ID of the booking category
  # @return [void]
  def insert_bookings(db, user_id, room_id, reason, start_time, end_time, booking_category)
    db.execute("INSERT INTO user_room_rel (u_id, r_id, reason, start_time, end_time, booking_category) VALUES (?, ?, ?, ?, ?, ?)", [user_id, room_id, reason, start_time, end_time, booking_category])
  end


  # Retrieves all rooms from the rooms table.
  #
  # @param db [SQLite3::Database] an open database connection
  # @return [Array<Hash>] an array of room hashes containing all columns from the
  #   rooms table
  def get_rooms(db)
    rooms = db.execute("SELECT rooms.id, rooms.name, room_category.category FROM room_category_rel INNER JOIN rooms ON rooms.id = room_category_rel.r_id INNER JOIN room_category ON room_category.id = room_category_rel.c_id")

    return rooms
  end


  # Retrieves all booking categories from the booking_category table.
  #
  # @param db [SQLite3::Database] an open database connection
  # @return [Array<Hash>] an array of category hashes containing all columns from
  #   the booking_category table
  def get_categories(db)
    booking_category = db.execute("SELECT * FROM booking_category")
    return booking_category
  end


  # Retrieves users from the users table, either by ID or by name search query.
  # If an ID is provided, returns a single user; otherwise returns all users whose
  # name matches the search query using SQL LIKE.
  #
  # @param db [SQLite3::Database] an open database connection
  # @param id [String] the user ID to look up; pass an empty string to search by name instead
  # @param query [String] a search string matched against user names using SQL LIKE;
  #   ignored if id is provided
  # @return [Hash, Array<Hash>, nil] a single user hash if id is provided and found;
  #   an array of user hashes if searching by query; or nil if id is provided but not found
  def get_users(db, id, query)
    if id == ""
      users = db.execute("SELECT * FROM users WHERE name LIKE ?", "%#{query}%")
    else
      users = db.execute("SELECT * FROM users WHERE id = ?", id).first
    end

    return users
  end


  # Looks up a single user by their username.
  #
  # @param db [SQLite3::Database] an open database connection
  # @param username [String] the username to search for
  # @return [Hash, nil] a hash of all user columns if found, or nil if no matching
  #   user exists
  def get_user_on_username(db, username)
    user = db.execute("SELECT * FROM users WHERE name = ?", [username]).first
    return user
  end


  # Inserts a new user record into the users table.
  #
  # @param db [SQLite3::Database] an open database connection
  # @param username [String] the username for the new account
  # @param password_digest [String] a BCrypt password digest of the user's password
  # @param teacher [Integer] 1 if the user is a teacher, 0 otherwise
  # @return [void]
  def insert_user(db, username, password_digest, teacher)
    db.execute("INSERT INTO users (name, pwd_digest, teacher) VALUES (?, ?, ?)", [username, password_digest, teacher])
  end


  # Deletes a user record from the users table by ID.
  #
  # @param db [SQLite3::Database] an open database connection
  # @param user_id [Integer] the ID of the user to delete
  # @return [void]
  def delete_user(db, user_id)
    db.execute("DELETE FROM users WHERE id = ?", user_id)
  end


  # Deletes a booking record from the user_room_rel table by ID.
  #
  # @param db [SQLite3::Database] an open database connection
  # @param booking_id [Integer] the ID of the booking to delete
  # @return [void]
  def delete_booking(db, booking_id)
    db.execute("DELETE FROM user_room_rel WHERE booking_id = ?", booking_id)
  end


  # Updates an existing booking record in the user_room_rel table.
  #
  # @param db [SQLite3::Database] an open database connection
  # @param user_id [Integer] the ID of the user making the booking
  # @param room_id [Integer] the ID of the room being booked
  # @param reason [String] the reason or description for the booking
  # @param start_time [String] the booking start time in "YYYY-MM-DD HH:MM:SS" format
  # @param end_time [String] the booking end time in "YYYY-MM-DD HH:MM:SS" format
  # @param booking_category [Integer] the ID of the booking category
  # @param id [Integer] the booking ID to update
  # @return [void]
  def update_booking(db, user_id, room_id, reason, start_time, end_time, booking_category, id)
    db.execute("UPDATE user_room_rel SET u_id = ?, r_id = ?, reason = ?, start_time = ?, end_time = ?, booking_category = ? WHERE booking_id = ?", [user_id, room_id, reason, start_time, end_time, booking_category, id])
  end

  # Updates a user's password digest in the users table.
  #
  # @param db [SQLite3::Database] an open database connection
  # @param id [Integer] the ID of the user whose password to update
  # @param pwd_digest [String] a BCrypt password digest of the new password
  # @return [void]
  def update_password(db, id, pwd_digest)
    db.execute("UPDATE users SET pwd_digest = ? WHERE id = ?", [pwd_digest, id])
  end
end