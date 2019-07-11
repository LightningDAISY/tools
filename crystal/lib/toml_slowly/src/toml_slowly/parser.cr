class TOML_Slowly::Parser
  @toml : String = ""
  #@sections = {} of String => String

  def self.parse(string : String)
    new(string).parse
  end

  def initialize(string : String)
    @toml = string
  end

  def trim(str : String)
    return str.sub(/^\s+/, "").sub(/\s+$/, "")
  end

  def getParentKeys(str : String) : Array(String)
    arr = @toml.scan(/\[(.+?)\]/)
    result = [] of String
    arr.each do |object|
      result << trim(object[1])
    end
    return result
  end

  def parseToplevel : Hash(String,String)
    splitKeys = [] of String
    parentKeys = getParentKeys(@toml)
    parentKeys.each do |parentKey|
      raise "invalid key-name #{parentKey}" if parentKey =~ /\|/
      splitKeys.push("\\[\\s*" + parentKey + "\\s*\]")
    end
    re = Regex.new(splitKeys.join("|"))
    contents = @toml.split(re)
    result = {} of String => String
    result["global"] = contents.shift
    parentKeys.each do |parentKey|
      if result[parentKey]?
        result[parentKey] += contents.shift
      else
        result[parentKey] ||= contents.shift
      end
    end
    return result
  end

  def parseSection(sectionKey : String, section : String) : Table
    result = Table.new
    section = trim(section) + "\n"
    words : Array(String) = section.split(//)
    isQuoted : Bool = false
    quote : String = ""
    isKey : Bool = true
    row : Hash(String, String) = {
      "key"   => "",
      "value" => "",
    }
    words.each do |chr|
      if chr == "\"" || chr == "'"
        if isQuoted
          if quote == chr
            isQuoted = false
            quote = ""
          else
            row[isKey ? "key" : "value"] += chr            
          end
        else
          isQuoted = true
          quote = chr
        end
      elsif chr == "="
        if isQuoted
          row[isKey ? "key" : "value"] += chr
        else
          isKey = isKey ? false : true
        end
      elsif chr == "\n"
        if isQuoted
          row[isKey ? "key" : "value"] += chr
        else
          if(row["key"].size > 0)
            resultKey = sectionKey + "." + trim(row["key"])
            result[resultKey] = trim(row["value"])
          end
          # init
          isQuoted = false
          quote = ""
          isKey = true
          row["key"] = row["value"] = ""
        end
      else
        row[isKey ? "key" : "value"] += chr
      end
    end
    return result
  end

  def parse
    toplevel : Hash(String,String) = parseToplevel()
    result = Table.new
    toplevel.each_key do |key|
      section = parseSection(key, toplevel[key])
      section.each_key do |key|
        result[key] = section[key]
      end
    end
    @toml = ""
    return result
  end
end
