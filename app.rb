require 'sinatra'
require 'slim'
require 'sqlite3'
require 'sinatra/reloader'
require 'bcrypt'
require 'time'
enable :sessions

def load_db(name)
  db = SQLite3::Database.new("db/#{name}.db")
  db.results_as_hash = true

  return db
end


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


def iso_time_object(time_str)
  time_arr = time_str.split("-")
  return Time.new(time_arr[0], time_arr[1], time_arr[2], time_arr[3], time_arr[4], time_arr[5])
end


def checkbox_to_bool(inp)
  if inp == "on"
    bool = 1
  else
    bool = 0
  end

  return bool
end


get("/") do
  slim(:login)
end


get("/index") do
  db = load_db("databas")

  @rooms = db.execute("SELECT * FROM rooms")
  @booking_category = db.execute("SELECT * FROM booking_category")

  slim(:index)
end


post("/login") do
    db = load_db("databas")

    session.delete(:user_message)
    session.delete(:login_message)

    username = params[:username]
    password = params[:password]

    if username != "" && password != ""
        user = db.execute("SELECT * FROM users WHERE name = ?", [username]).first
        if user != nil && BCrypt::Password.new(user["pwd_digest"]) == password
            session[:user] = user
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


post("/logout") do 
    session.clear

    redirect("/")
end


post("/user/add") do
    username = params[:username]
    password = params[:password]
    password_confirm = params[:password_confirm]
    teacher = params[:teacher]
    p teacher

    teacher = checkbox_to_bool(teacher)

    p teacher

    db = load_db("databas")

    usernames = db.execute("SELECT name FROM users")
    username_list = []

    usernames.each do |name|
        username_list << name["username"]
    end

    if password == password_confirm && username != "" && password != "" && !username_list.include?(username)
        password_digest = BCrypt::Password.create(password)
        db = SQLite3::Database.new("db/databas.db")
        db.execute("INSERT INTO users (name, pwd_digest, teacher) VALUES (?, ?, ?)", [username, password_digest])
        session[:user_message] = "User created!"
    else
        session[:user_message] = "Incorrect password or username already exists"
    end

    session.delete(:login_message)

    redirect("/")
end


post("/user/:id/delete") do 
    user_id = params[:id]

    db = SQLite3::Database.new("db/databas.db")
    db.execute("DELETE FROM users WHERE id = ?", user_id)

    session.clear
    redirect("/")
end


post("/user_room_rel") do
  room = params[:room]
  booking_category = params[:booking_category]
  reason = params[:reason]
  start_time = params[:start_time]
  end_time = params[:end_time]
  user_id = session[:user]["id"]

  for i in [start_time, end_time]
    i.gsub!("T", "-").gsub!(":", "-")
  end

  #kolla om klassrummet är bokat samma tid, om inte: boka det

  redirect("/index")
end


post("/rooms/search") do
  db = load_db("databas")
  query = params[:query]

  bookings = db.execute("SELECT user_room_rel.booking_id, rooms.name AS room_name, users.name AS user_name, user_room_rel.reason, user_room_rel.start_time, user_room_rel.end_time, booking_category.category FROM user_room_rel INNER JOIN rooms ON user_room_rel.r_id = rooms.id INNER JOIN users ON user_room_rel.u_id = users.id INNER JOIN booking_category ON user_room_rel.booking_category = booking_category.id  WHERE rooms.name LIKE ?", "%#{query}%")

  unfrozen_bookings = Array.new()
  for i in bookings
    unfrozen_bookings << i
  end
  bookings = sort_booking_arr(unfrozen_bookings)

  session[:bookings] = bookings

  redirect("/index")
end