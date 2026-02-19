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

    return sort(part1).append(partElement).concat(sort(part2))

  end
end


def iso_time_object(time_str)
  # jag vill skriva in men time_arr i Time.new() för att på ut ett tids-objekt som jag sedan kan returna till sort_booking_arr()
  time_arr = time_str.split("-")
  return Time.new()
end


get("/index") do
  slim(:index)
end

post("/rooms/search") do
  db = load_db("databas")
  query = params[:query]

  bookings = db.execute("SELECT user_room_rel.booking_id, rooms.name AS room_name, users.name AS user_name, user_room_rel.reason, user_room_rel.start_time, user_room_rel.end_time, booking_category.category FROM user_room_rel INNER JOIN rooms ON user_room_rel.r_id = rooms.id INNER JOIN users ON user_room_rel.u_id = users.id INNER JOIN booking_category ON user_room_rel.booking_category = booking_category.id  WHERE rooms.name LIKE ?", "%#{query}%")

  session[:bookings] = bookings

  redirect("/index")
end