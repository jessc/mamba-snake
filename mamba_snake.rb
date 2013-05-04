#!/usr/bin/env ruby

# 2013-05
# Jesse Cummins
# https://github.com/jessc
# with advice from Ryan Metzler

=begin
# Bug List / TODO:

- So here's what I'm thinking: The map can keep track of the animals, but the game asks the animal for a new position,
  checks if it's OK with map, then sets map equal to it if so

- just keep throwing yourself at the problem!
- rabbit can leave the map
- top level game should control the map and snake and rabbits
- when the game starts the snake does not immediately move
- if rabbit walled in by snake turns and goes different direction
- sometimes the snake does not eat the rabbit
- the rabbit can be on top of the snake
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
end

class Rabbit
  attr_reader :color, :pos
  def initialize(map)
    @map = map
    @color = Gosu::Color::WHITE
    @hop_direction = :right
    @hop_distance = 2

    breed
  end

  def breed
    @pos = {:x => rand(@map.width + 1), :y => rand(@map.height + 1)}
  end

  def update
    hop
  end

  def hop
    if @hop_distance > 0
      @pos[:x] += case @hop_direction
                  when :left  then -1
                  when :right then 1
                  else 0
                  end
      @pos[:y] += case @hop_direction
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
  def initialize(map)
    @color = Gosu::Color::BLACK
    @map = map
    @direction = :right

    @parts = []
    (10..15).each { |n| @parts << {:x => n, :y => @map.height / 2} }
    @pos = parts.shift
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

  def update
    @pos[:x] += case @direction
                when :left  then -1
                when :right then 1
                else 0
                end

    @pos[:y] += case @direction
                when :up   then -1
                when :down then 1
                else 0
                end

    @parts << {:x => @pos[:x], :y => @pos[:y]}
    @parts.shift
  end

  def grow
    5.times { @parts.unshift(@pos) }
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

  def initialize
    super(SCREEN_WIDTH, SCREEN_HEIGHT, false, 100)
    @font = Gosu::Font.new(self, Gosu.default_font_name, 50)
    self.caption = TITLE
    new_game
  end

  def new_game
    @map = Map.new(MAP_WIDTH, MAP_HEIGHT)
    @rabbit = Rabbit.new(@map)
    @snake = Mamba.new(@map)
  end

  def update
    @rabbit.update
    @snake.update

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
    draw_quad(place[:x]*10, place[:y]*10, color,
              place[:x]*10+10, place[:y]*10, color,
              place[:x]*10, place[:y]*10+10, color,
              place[:x]*10+10, place[:y]*10+10, color,
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

