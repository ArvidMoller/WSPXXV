require_relative './model.rb'
require 'sinatra'
require 'slim'
require 'sqlite3'
require 'sinatra/reloader'
require 'bcrypt'
require 'time'
enable :sessions

include Model

# Sorts an array of booking hashes in ascending chronological order by start time.
# Uses a recursive quicksort algorithm with the first element as the pivot.
#
# @param arr [Array<Hash>] array of booking hashes, each containing a "start_time" key
#   in the format "YYYY-MM-DD-HH-MM-SS"
# @return [Array<Hash>] a new array sorted by start_time in ascending order
def sort_booking_arr(arr)
  if arr.length <= 1
    return arr
  else
    partElement = arr[0]
    partTime = iso_time_object(arr[0]["start_time"])

    arr.delete_at(0)

    part1 = Array.new
    part2 = Array.new

    arr.each_entry do |e|
      if iso_time_object(e["start_time"]) < partTime
        part1.append(e)
      else
        part2.append(e)
      end
    end

    return sort_booking_arr(part1).append(partElement).concat(sort_booking_arr(part2))
  end
end


# Converts a hyphen-separated datetime string into a Ruby Time object.
#
# @param time_str [String] a datetime string in the format "YYYY-MM-DD-HH-MM-SS"
# @return [Time] the corresponding Time object
def iso_time_object(time_str)
  time_arr = time_str.split("-")
  return Time.new(time_arr[0], time_arr[1], time_arr[2], time_arr[3], time_arr[4], time_arr[5])
end


# Converts an HTML checkbox value to a boolean integer suitable for database storage.
#
# @param inp [String, nil] the checkbox parameter value; "on" if checked, nil or any
#   other value if unchecked
# @return [Integer] 1 if the checkbox is checked, 0 otherwise
def checkbox_to_bool(inp)
  if inp == "on"
    bool = 1
  else
    bool = 0
  end

  return bool
end


# Checks whether two time intervals overlap.
# Two intervals overlap if one starts before the other ends, and vice versa.
#
# @param a_start [Time] the start time of interval A
# @param a_end [Time] the end time of interval A
# @param b_start [Time] the start time of interval B
# @param b_end [Time] the end time of interval B
# @return [Boolean] true if the intervals overlap, false otherwise
def time_overlap(a_start, a_end, b_start, b_end)
  return a_start < b_end && b_start < a_end
end


# Queries bookings from the database, sorts them, and stores them in the session.
#
# @param databas [String] the name of the database file to load (without extension)
# @param query [String] a search query string used to filter bookings
# @return [void]
def search_bookings(databas, query)
  db = load_db(databas)

  bookings = get_bookings(query, db)

  unfrozen_bookings = Array.new()
  for i in bookings
    unfrozen_bookings << i
  end
  bookings = sort_booking_arr(unfrozen_bookings)

  session[:bookings] = bookings
end


# Deletes all bookings whose end time has already passed.
# Intended to be called before rendering views that display current bookings.
#
# @param db [SQLite3::Database] an open database connection
# @return [void]
def remomve_old(db)
  bookings = get_bookings("", db)

  bookings.each do |booking|
    if iso_time_object(booking["end_time"]) < Time.new
      delete_booking(booking["booking_id"])
    end
  end
end


# @!group Filters

# Before filter for the /index route.
# Redirects unauthenticated users to the login page.
before('/index') do
  if session[:user] == nil
    redirect("/")
  end
end

# @!endgroup


# @!group Routes

# Renders the login page.
#
# @return [String] rendered Slim template for the login view
get("/") do
  slim(:login)
end


# Renders the main index page with available rooms and booking categories.
# Also removes expired bookings before rendering.
#
# @return [String] rendered Slim template for the index view
get("/index") do
  db = load_db("databas")
  remomve_old(db)

  @rooms = get_rooms(db)
  @booking_category = get_categories(db)

  slim(:index)
end


# Renders the edit page for a specific booking.
#
# @param id [Integer] the ID of the booking to edit, provided as a URL parameter
# @return [String] rendered Slim template for the edit view
get("/user_room_rel/:id/edit") do
  db = load_db("databas")
  id = params[:id]

  if session[:user_message] != "All fields are not filled in."
    session.delete(:user_message)
  end

  @rooms = get_rooms(db)
  @booking_category = get_categories(db)
  @booking = get_booking_on_id(db, id)

  slim(:edit)
end


# Authenticates a user and creates a session on success.
# Adds a 0.5 second delay to slow brute-force attempts.
# Redirects to /index on success, or back to / with an error message on failure.
#
# @param username [String] the submitted username
# @param password [String] the submitted plaintext password
# @return [void]
post("/login") do
  sleep(0.5)

  db = load_db("databas")

  session.delete(:user_message)
  session.delete(:login_message)

  username = params[:username]
  password = params[:password]

  if username != "" && password != ""
    user = get_user_on_username(db, username)
    if user != nil && BCrypt::Password.new(user["pwd_digest"]) == password
      session[:user] = user
      search_bookings("databas", "")
      redirect("/index")
    else
      session[:login_message] = "Incorrect username or password"
      redirect("/")
    end
  else
    session[:login_message] = "Incorrect username or password"
    redirect("/")
  end
end


# Logs out the current user by clearing the session and redirecting to the login page.
#
# @return [void]
post("/logout") do
  session.clear

  redirect("/")
end


# Creates a new user account.
# Validates that passwords match, that required fields are filled in, and that
# the username is not already taken. Stores a BCrypt digest of the password.
#
# @param username [String] the desired username
# @param password [String] the desired password
# @param password_confirm [String] the password confirmation
# @param teacher [String, nil] checkbox value; "on" if the user is a teacher
# @return [void]
post("/user/add") do
  username = params[:username]
  password = params[:password]
  password_confirm = params[:password_confirm]
  teacher = params[:teacher]

  teacher = checkbox_to_bool(teacher)

  db = load_db("databas")

  usernames = get_users(db)
  username_list = []

  usernames.each do |name|
    username_list << name["username"]
  end

  if password == password_confirm && username != "" && password != "" && !username_list.include?(username)
    password_digest = BCrypt::Password.create(password)
    insert_user(username, password_digest, teacher)
    session[:user_message] = "User created!"
  else
    session[:user_message] = "Incorrect password or username already exists"
  end

  session.delete(:login_message)

  redirect("/")
end


# Deletes a user account and clears the current session.
#
# @param id [Integer] the ID of the user to delete, provided as a URL parameter
# @return [void]
post("/user/:id/delete") do
  user_id = params[:id]

  db = load_db("databas")
  delete_user(user_id)

  session.clear
  redirect("/")
end


# Creates a new room booking if the requested time slot is available.
# Validates that all required fields are present, that the start time is in the future,
# and that the chosen room has no overlapping bookings.
#
# @param room [String] the ID of the room to book
# @param booking_category [String] the category ID for the booking
# @param reason [String] the reason or description for the booking
# @param start_time [String] the booking start time in ISO 8601 datetime-local format
# @param end_time [String] the booking end time in ISO 8601 datetime-local format
# @return [void]
post("/user_room_rel") do
  db = load_db("databas")

  room_id = params[:room]
  booking_category = params[:booking_category]
  reason = params[:reason]
  start_time = params[:start_time]
  end_time = params[:end_time]
  user_id = session[:user]["id"]

  if room_id == nil || booking_category == nil || reason == "" || start_time == "" || end_time == ""
    session[:user_message] = "All fields are not filled in."
    redirect("/index")
  end

  bookings = get_booking_on_room_id(db, room_id)

  for i in [start_time, end_time]
    i.gsub!("T", "-").gsub!(":", "-")
  end

  start_time_object = iso_time_object(start_time)
  end_time_object = iso_time_object(end_time)

  if start_time_object > Time.new
    bookings.each do |booking|
      if time_overlap(iso_time_object(booking["start_time"]), iso_time_object(booking["end_time"]), start_time_object, end_time_object) == false
        insert_bookings(user_id, room_id, reason, start_time, end_time, booking_category)

        session[:user_message] = "Room booked!"
        search_bookings("databas", "")
        redirect("/index")
      end
    end

    if bookings.length == 0
      insert_bookings(user_id, room_id, reason, start_time, end_time, booking_category)

      session[:user_message] = "Room booked!"
      search_bookings("databas", "")
      redirect("/index")
    end
  end

  session[:user_message] = "The room is not avalible during this time."
  redirect("/index")
end


# Updates an existing booking with new details, if the new time slot is available.
# Validates required fields, checks that the start time is in the future, and ensures
# no overlapping bookings exist for the chosen room.
#
# @param id [Integer] the ID of the booking to update, provided as a URL parameter
# @param room [String] the ID of the room to book
# @param booking_category [String] the category ID for the booking
# @param reason [String] the reason or description for the booking
# @param start_time [String] the new start time in ISO 8601 datetime-local format
# @param end_time [String] the new end time in ISO 8601 datetime-local format
# @return [void]
post("/user_room_rel/:id/update") do
  db = load_db("databas")

  booking_id = params[:id]
  room_id = params[:room]
  booking_category = params[:booking_category]
  reason = params[:reason]
  start_time = params[:start_time]
  end_time = params[:end_time]
  user_id = session[:user]["id"]

  if room_id == nil || booking_category == nil || reason == "" || start_time == "" || end_time == ""
    session[:user_message] = "All fields are not filled in."
    redirect("/user_room_rel/#{booking_id}/edit")
  end

  bookings = get_booking_on_room_id(db, room_id)

  for i in [start_time, end_time]
    i.gsub!("T", "-").gsub!(":", "-")
  end

  start_time_object = iso_time_object(start_time)
  end_time_object = iso_time_object(end_time)

  if start_time_object > Time.new
    bookings.each do |booking|
      if time_overlap(iso_time_object(booking["start_time"]), iso_time_object(booking["end_time"]), start_time_object, end_time_object) == false
        insert_bookings(user_id, room_id, reason, start_time, end_time, booking_category)

        session.delete(:user_message)
        search_bookings("databas", "")
        redirect("/index")
      end
    end

    if bookings.length == 0
      insert_bookings(user_id, room_id, reason, start_time, end_time, booking_category)

      session[:user_message] = "Room booked!"
      search_bookings("databas", "")
      redirect("/index")
    end
  end

  session[:user_message] = "The room is not avalible during this time."
  redirect("/user_room_rel/#{booking_id}/edit")
end


# Cancels an in-progress booking edit and redirects back to the index page.
#
# @return [void]
post("/user_room_rel/cancel_edit") do
  redirect("/index")
end


# Deletes a booking and refreshes the session's booking list.
#
# @param id [Integer] the ID of the booking to delete, provided as a URL parameter
# @return [void]
post("/user_room_rel/:id/delete") do
  booking_id = params[:id]

  db = load_db("databas")
  delete_booking(booking_id)

  search_bookings("databas", "")

  redirect("/index")
end


# Searches bookings by a query string, stores results in the session, and redirects to index.
#
# @param query [String] the search query to filter bookings by
# @return [void]
post("/rooms/search") do
  query = params[:query]

  search_bookings("databas", query)

  redirect("/index")
end

# @!endgroup