#!/usr/bin/env ruby

# 2013-05
# Jesse Cummins
# https://github.com/jessc
# with advice from Ryan Metzler

=begin
# Bug List / TODO:

- So here's what I'm thinking: The map can keep track of the animals,
  but the game asks the animal for a new position,
  checks if it's OK with map, then sets map equal to it if so

- just keep throwing yourself at the problem!
- rabbit can leave the map
- top level game should control the map and snake and rabbits
- if rabbit walled in by snake, rabbit turns and goes different direction
- sometimes when the rabbit breeds it will start
  right where the snake is and not appear
- snake does not die when it collides with wall or itself


Other Features:
- allow for multiple rabbits
- add highscore
- multiplayer game
- play against a snake AI
- rabbits can breed when near each other, grow old and die
- could go up trees to go to a new level
- snake could move diagonally
- rabbits could exhibit swarm behavior

=end

require 'gosu'
require 'yaml'

class Map
  attr_reader :width, :height

  def initialize(width, height)
    @map = Hash.new(:empty)
    @width = width
    @height = height

    (0...@height).each do |y|
      (0...@width).each do |x|
        @map[[x, y]] = :border if is_border(x, y)
      end
    end
  end

  def is_border(x, y)
    x == 0 || x == @width - 1 || y == 0 || y == @height - 1
  end

  def display
    (0...@height).each do |y|
      (0...@width).each do |x|
        print @map[[x, y]].to_s[0]
      end
      p ''
    end
  end

  def [](x, y)
    @map[[x, y]]
  end

  def []=(x, y, val)
    @map[[x, y]] = val
  end
end

class Rabbit
  attr_reader :color, :pos
  def initialize(map_width, map_height)
    @map_width = map_width
    @map_height = map_height
    @color = Gosu::Color::WHITE
    @hop_direction = :right
    @hop_distance = 2

    breed
  end

  def breed
    @pos = [rand(@map_width + 1), rand(@map_height + 1)]
  end

  def update
    hop
  end

  def hop
    if @hop_distance > 0
      @pos[0] += case @hop_direction
                  when :left  then -1
                  when :right then 1
                  else 0
                  end
      @pos[1] += case @hop_direction
                  when :up   then -1
                  when :down then 1
                  else 0
                  end
      @hop_distance -= 1
    else
      @hop_distance = 2
      @hop_direction = [:left, :right, :up, :down].sample
    end
  end
end


class Mamba
  attr_reader :color, :pos, :parts, :direction
  def initialize(map_width, map_height)
    @color = Gosu::Color::BLACK
    @direction = :right

    @parts = []
    (1..5).each { |n| @parts << [(map_width / 2) - n, map_height / 2] }
    @pos = @parts.shift
    p @pos
  end

  def update
    @pos[0] += case @direction
                when :left  then -1
                when :right then 1
                else 0
                end

    @pos[1] += case @direction
                when :up   then -1
                when :down then 1
                else 0
                end

    # pushes new head on start of snake, pops end
    @parts.unshift [@pos[0], @pos[1]]
    @parts.pop
    p @parts
  end

  def grow
    # pushes current spot on end of snake
    # Because the snake will have the same x, y coordinates multiple times,
    # it will not properly collide with itself.
    5.times { @parts << @pos }
  end

  def direction(id)
    @direction = case id
                 when Gosu::KbRight then @direction == :left ? @direction : :right
                 when Gosu::KbUp    then @direction == :down ? @direction : :up
                 when Gosu::KbLeft  then @direction == :right ? @direction : :left
                 when Gosu::KbDown  then @direction == :up ? @direction : :down
                 else @direction
                 end
  end
end


class MambaSnakeGame < Gosu::Window
  module Z
    Background, Map, Text, Snake, Rabbit = *1..100
  end

  settings = YAML.load_file "config.yaml"

  MAP_WIDTH = settings["map_width"]
  MAP_HEIGHT = settings["map_height"]
  SCREEN_WIDTH = settings["screen_width"]
  SCREEN_HEIGHT = settings["screen_height"]

  TITLE = "Hungry Mamba!"
  TOP_COLOR = Gosu::Color::YELLOW
  BOTTOM_COLOR = Gosu::Color::GREEN
  TEXT_COLOR = Gosu::Color::BLACK

  @paused = false

  def initialize
    super(SCREEN_WIDTH, SCREEN_HEIGHT, false, 100)
    @font = Gosu::Font.new(self, Gosu.default_font_name, 50)
    self.caption = TITLE
    new_game
  end

  def new_game
    @map = Map.new(MAP_WIDTH, MAP_HEIGHT)
    @rabbit = Rabbit.new(MAP_WIDTH, MAP_HEIGHT)
    @snake = Mamba.new(MAP_WIDTH, MAP_HEIGHT)
  end

  def update
    return if @paused

    @snake.update
    @rabbit.update

    if @snake.pos == @rabbit.pos
      @snake.grow
      while @snake.parts.index(@rabbit.pos)
        @rabbit.breed
      end
    end
  end

  def draw
    draw_background
    draw_animal(@rabbit.pos, @rabbit.color, Z::Rabbit)
    @snake.parts.each { |part| draw_animal(part, @snake.color, Z::Snake) }
  end

  def draw_background
    draw_quad(
      0,     0,      TOP_COLOR,
      SCREEN_WIDTH, 0,      TOP_COLOR,
      0,     SCREEN_HEIGHT, BOTTOM_COLOR,
      SCREEN_WIDTH, SCREEN_HEIGHT, BOTTOM_COLOR,
      Z::Background)
  end

  def draw_animal(place, color, layer)
    draw_quad(place[0]*10, place[1]*10, color,
              place[0]*10+10, place[1]*10, color,
              place[0]*10, place[1]*10+10, color,
              place[0]*10+10, place[1]*10+10, color,
              layer)
  end

  def button_down(id)
    case id
      when Gosu::KbSpace  then @paused = !@paused
      when Gosu::KbEscape then close
      when Gosu::KbR then new_game
      when Gosu::KbE then @map.display
    end

    if button_down?(Gosu::KbLeftMeta) && button_down?(Gosu::KbQ) then close; end
    if button_down?(Gosu::KbRightMeta) && button_down?(Gosu::KbQ) then close; end

    @snake.direction(id)
  end
end


MambaSnakeGame.new.show

