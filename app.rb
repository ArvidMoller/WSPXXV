require 'sinatra'
require 'slim'
require 'sqlite3'
require 'sinatra/reloader'
require 'bcrypt'

def load_db(name)
  db = SQLite3::Database.new("db/#{name}.db")
  db.results_as_hash = true

  return db
end


get("/index") do
  slim(:index)
end

post("/rooms/search") do
  db = load_db("databas")

  room_search = params[:room_search]
end