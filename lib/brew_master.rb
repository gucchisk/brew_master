# frozen_string_literal: true

require "ripper"
require "json"

class BrewMaster
  VERSION = "0.1.0"

  def initialize(str)
    lex = Ripper.lex(str)
    @lex = lex
    lines = []
    current = 1
    line = []
    nl = false
    lineno = []
    lex.each do |token|
      type = token[1]
      if token[0][0] != current then
        lineno.push(current)
        if nl
          if line.size != 0
            lines.push({lineno: lineno, line: line})
          end
          lineno = []
          line = []
        end
        current += 1
      end
      if type != :"on_sp" && type != :"on_ignored_nl" then
        line.push({type: token[1], token: token[2], state: token[3]})
        if type == :"on_nl"
          nl = true
        else
          nl = false
        end
      end
    end

    @lines = lines
    @values = {}
    @info = {}

    lines.each do |linedata|
      case linedata[:line][0][:type]
      when :"on_const" then
        on_const(linedata)
      when :"on_ident" then
        on_ident(linedata)
      end
    end
  end

  def lex
    @lex
  end

  def print
    @lines.each do |line|
      pp line
    end
    return
  end

  def lines
    @lines
  end

  def line(num)
    @lines[num]
  end

  def values
    @values
  end

  def info
    @info
  end

  def json
    JSON.dump(@info)
  end

  # event
  def on_const(linedata)
    line = linedata[:line]
    name = line[0][:token]
    @values[name] = get_value(line)
  end

  def on_ident(linedata)
    line = linedata[:line]
    case line[0][:token]
    when "version" then
      @info[:version] = {value: get_value(line)[:value], lineno: linedata[:lineno]}
    when "url" then
      i, _ = get_token(line, :"on_comma")
      @info[:url] = {value: get_value(line, 1, i - 1), lineno: linedata[:lineno]}
      i, id = get_token(line, :"on_ident", i)
      case id
      when "tag" then
        @info[:url][:tag] = get_value(line, i + 1)[:value]
      when "revision" then
        @info[:url][:revision] = get_value(line, i + 1)[:value]
      when "branch" then
        @info[:url][:branch] = get_value(line, i + 1)[:value]
      end
    when "revision" then
      @info[:revision] = {value: get_value(line)[:value], lineno: linedata[:lineno]}
    else
    end
  end

  def get_token(line, type, s=1, e=line.size-1)
    for n in s..e do
      token = line[n]
      if token[:type] == type
        return n, token[:token]
      end
    end
    nil
  end

  def get_value(line, s=1, e=line.size-1)
    type = nil
    value = ""
    for n in s..e do
      token = line[n]
      case token[:type]
      when :"on_int" then
        type = "int"
        value = token[:token]
      when :"on_tstring_content" then
        type = "string"
        value += token[:token]
      when :"on_const" then
        v = @values[token[:token]]
        type = v[:type]
        value += v[:value]
      else
      end
    end
    if type == nil
      return nil
    end
    return {type: type, value: value}
  end
end

class AddText < Ripper::Filter
  def initialize(str, text, id, before)
    super(str)
    @text = text
    @id = id
    @in = false
  end

  def on_default(event, token, data)
    pp event.to_s + ":" + token
    data + token
  end

  def on_ident(token, data)
    pp "on_ident:" + token
    if token == @id
      @in = true
    end
    data + token
  end

  def on_nl(token, data)
    pp "on_nl"
    if @in
      @in = false
      if !@before
        return data + token + @c_sp + @text + "\n"
      end
    end
    data + token
  end

  def on_sp(token, data)
    pp "on_sp:" + token
    if !@in
      @c_sp = token
    end
    data + token
  end
end
