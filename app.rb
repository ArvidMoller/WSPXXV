require_relative './model.rb'
require 'sinatra'
require 'slim'
require 'sqlite3'
require 'sinatra/reloader'
require 'bcrypt'
require 'time'
enable :sessions

include Model

$login_attemps = 0

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
# @param query [String] a search query string used to filter bookings by room name
# @return [void]
def search_bookings(databas, query)
  db = load_db(databas)

  bookings = get_bookings(db, query)

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
  bookings = get_bookings(db, "")

  bookings.each do |booking|
    if iso_time_object(booking["end_time"]) < Time.new
      delete_booking(db, booking["booking_id"])
    end
  end
end


def check_user_on_bookings(db, booking_id)
  u_id_booking = db.execute("SELECT u_id FROM user_room_rel WHERE booking_id = ?", booking_id).first
  if u_id_booking.class != "i"
    u_id_booking = u_id_booking["u_id"]
  end

  if session[:user]["id"] != u_id_booking
    p "User ID: #{session[:user]["id"]} | Booking ID: #{u_id_booking}"
    redirect("/index")
  end
end


# @!group Filters

# Before filter for the /index route.
# Redirects unauthenticated users to the login page.
#
# @return [void]
before('/index') do
  if session[:user] == nil
    redirect("/")
  end
end

# @!endgroup


# @!group Routes

# Renders the login page.
# Displays the login and user registration form.
#
# @return [String] rendered Slim template for the login view
get("/") do
  slim(:login)
end


# Renders the main index page with available rooms and booking categories.
# Also removes expired bookings before rendering and clears cached user search results.
#
# @return [String] rendered Slim template for the index view
get("/index") do
  db = load_db("databas")
  remomve_old(db)
  session.delete(:users)

  @rooms = get_rooms(db)
  @booking_category = get_categories(db)

  slim(:index)
end


# Renders the users management page with a list of all users.
# Displays cached search results from the session if available, otherwise fetches all users.
#
# @return [String] rendered Slim template for the users view
get("/users") do
  db = load_db("databas")

  if session[:users] == nil
    @users = get_users(db, "", "")
  else
    @users = session[:users]
  end

  slim(:users)
end


# Renders the edit page for a specific booking.
# Prepopulates the form with the current booking details and available rooms and categories.
#
# @return [String] rendered Slim template for the edit booking view
get("/user_room_rel/:id/edit") do
  db = load_db("databas")
  id = params[:id]

  if !(session[:user_message] == "All fields are not filled in." || session[:user_message] == "Time for booking is not allowed.")
    session.delete(:user_message)
  end

  @rooms = get_rooms(db)
  @booking_category = get_categories(db)
  @booking = get_booking_on_id(db, id)

  slim(:"user_room_rel/edit")
end


# Renders the edit page for a specific user account.
# Prepopulates the form with the current user's details.
#
# @return [String] rendered Slim template for the edit user view
get("/user/:id/edit") do
  id = params[:id]

  db = load_db("databas")
  session.delete(:users)

  @users = get_users(db, id, "")

  slim(:"users/edit")
end


# Authenticates a user and creates a session on success.
# Verifies the username and password against the database using BCrypt.
# Implements brute-force protection by adding a 5 second delay after 4 failed attempts.
# Redirects to /index on successful authentication, or back to / with an error message on failure.
#
# @return [void]
post("/login") do
  $login_attemps += 1

  if $login_attemps > 4
    sleep(5)
  end

  db = load_db("databas")

  session.delete(:user_message)
  session.delete(:login_message)

  username = params[:username]
  password = params[:password]

  if username != "" && password != ""
    user = get_user_on_username(db, username)
    if user != nil && BCrypt::Password.new(user["pwd_digest"]) == password
      session[:user] = user

      $login_attemps = 0
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


# Creates a new user account with the specified username, password, and permissions.
# Validates that passwords match, that all required fields are filled in, and that
# the username is not already in use. Stores a BCrypt digest of the password.
# On success, displays a confirmation message; on failure, displays an error message.
#
# @return [void]
post("/user/add") do
  username = params[:username]
  password = params[:password]
  password_confirm = params[:password_confirm]
  teacher = params[:teacher]

  teacher = checkbox_to_bool(teacher)

  db = load_db("databas")

  users = get_users(db, "", "")
  username_list = []

  users.each do |user|
    username_list << user["name"]
  end

  if password == password_confirm && username != "" && password != "" && !username_list.include?(username)
    password_digest = BCrypt::Password.create(password)
    insert_user(db, username, password_digest, teacher)
    session[:user_message] = "User created!"
  else
    session[:user_message] = "Incorrect password or username already exists"
  end

  session.delete(:login_message)

  redirect("/")
end


# Updates a user's password after validating that the two password entries match.
# Stores a BCrypt digest of the new password in the database.
# On success, displays a confirmation message; on failure, displays an error message.
#
# @return [void]
post("/user/:id/update") do
  id = params[:id]
  password = params[:password]
  password_confirm = params[:password_confirm]

  db = load_db("databas")
  session.delete(:user_message)

  if session[:user]["id"] != id.to_i
    p "#{session[:user]["id"]} | #{id}"
    session[:user_message] = "An error has occured"
    redirect("/user/#{id}/edit")
  end

  if password == password_confirm && password != ""
    password_digest = BCrypt::Password.create(password)

    update_password(db, id, password_digest)
    session[:user_message] = "Password updated"
  else
    session[:user_message] = "Incorrect password"
  end

  redirect("/user/#{id}/edit")
end


# Deletes a user account from the database.
# If the deleted user is the current logged-in user, clears the session and redirects to login.
# If called from the admin users page, redirects back to the users management page.
#
# @return [void]
post("/user/:id/delete/:info") do
  db = load_db("databas")

  user_id = params[:id]
  info = params[:info]

  if info == "logout" && session[:user]["id"] == user_id
    delete_user(db, user_id)
    session.clear
    redirect("/")
  elsif info == "admin" && session[:user]["teacher"] == 1
    delete_user(db, user_id)
    redirect("/users")
  else
    redirect("/index")
  end
end


# Creates a new room booking if the requested time slot is available.
# Validates that all required fields are present, that the start time is in the future,
# that the booking duration is less than 10 hours, that the start time is before the end time,
# and that the chosen room has no overlapping bookings.
# On success, stores the booking and displays a confirmation message.
# On failure, displays an appropriate error message.
#
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

  if start_time_object > Time.new && end_time_object - start_time_object < 10*60*60 && start_time_object < end_time_object
    bookings.each do |booking|
      if time_overlap(iso_time_object(booking["start_time"]), iso_time_object(booking["end_time"]), start_time_object, end_time_object) == false
        insert_bookings(db, user_id, room_id, reason, start_time, end_time, booking_category)

        session[:user_message] = "Room booked!"
        search_bookings("databas", "")
        redirect("/index")
      end
    end

    if bookings.length == 0
      insert_bookings(db, user_id, room_id, reason, start_time, end_time, booking_category)
      session[:user_message] = "Room booked!"
      search_bookings("databas", "")
      redirect("/index")
    end
  else
    session[:user_message] = "Time for booking is not allowed."
    redirect("/index")
  end

  session[:user_message] = "The room is not avalible during this time."
  redirect("/index")
end


# Updates an existing booking with new details, if the new time slot is available.
# Validates that all required fields are present, that the start time is in the future,
# that the booking duration is less than 10 hours, that the start time is before the end time,
# and that no overlapping bookings exist for the chosen room.
# On success, updates the booking and displays a confirmation message.
# On failure, displays an appropriate error message.
#
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

  check_user_on_bookings(db, booking_id)
  
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

  if start_time_object > Time.new && end_time_object - start_time_object < 10*60*60 && start_time_object < end_time_object
    bookings.each do |booking|
      if time_overlap(iso_time_object(booking["start_time"]), iso_time_object(booking["end_time"]), start_time_object, end_time_object) == false
        update_booking(db, user_id, room_id, reason, start_time, end_time, booking_category, booking_id)

        session.delete(:user_message)
        search_bookings("databas", "")
        redirect("/index")
      end
    end

    if bookings.length == 0
      update_booking(db, user_id, room_id, reason, start_time, end_time, booking_category, booking_id)

      session.delete(:user_message)
      search_bookings("databas", "")
      redirect("/index")
    end
  else
    session[:user_message] = "Time for booking is not allowed."
    redirect("/user_room_rel/#{booking_id}/edit")
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


# Deletes a booking from the database and refreshes the session's booking list.
#
# @return [void]
post("/user_room_rel/:id/delete") do
  booking_id = params[:id]
  db = load_db("databas")

  check_user_on_bookings(db, booking_id)
  delete_booking(db, booking_id)

  search_bookings("databas", "")

  redirect("/index")
end


# Searches for bookings by a query string, stores results in the session, and redirects to the index page.
# Uses the query to filter bookings by room name.
#
# @return [void]
post("/rooms/search") do
  query = params[:query]

  search_bookings("databas", query)

  redirect("/index")
end


# Searches for users by a query string, stores results in the session, and redirects to the users page.
# Uses the query to filter users by username.
#
# @return [void]
post("/users/search") do
  query = params[:query]
  db = load_db("databas")

  session[:users] = get_users(db, "", query)

  redirect("/users")
end

# @!endgroup