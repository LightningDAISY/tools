require "./toml_slowly/*"

module TOML_Slowly
  alias Type = Bool | Int64 | Float64 | String | Time | Array(Type) | Hash(String, Type)
  alias Table = Hash(String, Type)

  def self.parse(string : String) : TOML_Slowly::Table
    Parser.parse(string)
  end
end

#
# example:
#
#  #! /usr/bin/env crystal
#  require "toml_slowly"
#  
#  def main()
#    toml_string = %(
#  [default.a]
#  title = "TOML Example"
# 
#  [default.b]
#  [owner]
#  name = "Lance Uppercut"
#  dob = 1979-05-27T07:32:00Z
#  )
# 
#  hash = TOML_Slowly.parse(toml_string)
#  p hash
#  end
#
#  main()
#
# Result:
#
#  {"default.a.title" => "TOML Example", "owner.name" => "Lance Uppercut", "owner.dob" => "1979-05-27T07:32:00Z"}
#

