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
- if rabbit walled in by snake, rabbit should turn and go different direction
- sometimes when the rabbit breeds it will start
  right where the snake is and not appear
- when game starts, if a different direction that :right is chosen, 
  snake stretches weirdly (press up right quickly)
- if direction keys are pressed rapidly the snake can run on top
  of itself and instantly die

Other Features:
- add time
- add instructions at top of border
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
  attr_reader :color
  attr_accessor :pos
  def initialize(x, y)
    @color = Gosu::Color::WHITE
    @hop_direction = :right
    @hop_default = 1
    @hop_distance = @hop_default
    @pos = [x, y]
  end

  def update
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
      @hop_distance = @hop_default
      @hop_direction = [:left, :right, :up, :down].sample
    end
  end
end


class Mamba
  attr_reader :color, :head, :parts, :direction
  def initialize(map_width, map_height)
    @color = Gosu::Color::BLACK
    @direction = :right
    @grow_length = 5
    @start_size = 5

    @parts = []
    (0..@start_size).each { |n| @parts << [(map_width / 2) - n, (map_height / 2)] }
    @head = @parts.pop
    # p @head
  end

  def update
    # p @parts
    @head[0] += case @direction
                when :left  then -1
                when :right then 1
                else 0
                end
    @head[1] += case @direction
                when :up   then -1
                when :down then 1
                else 0
                end

    @parts.unshift [@head[0], @head[1]]
    @parts.pop
  end

  def grow
    @grow_length.times { @parts << @parts[-1] }
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
    Border, Background, Map, Text, Snake, Rabbit = *1..100
  end

  settings = YAML.load_file "config.yaml"

  MAP_WIDTH = settings["map_width"]
  MAP_HEIGHT = settings["map_height"]
  SCREEN_WIDTH = settings["screen_width"]
  SCREEN_HEIGHT = settings["screen_height"]

  TITLE = "Hungry Mamba!"
  TOP_COLOR = Gosu::Color::GREEN
  BOTTOM_COLOR = Gosu::Color::GREEN
  TEXT_COLOR = Gosu::Color::BLACK
  BORDER_COLOR = Gosu::Color::RED

  @paused = false

  def initialize
    super(SCREEN_WIDTH, SCREEN_HEIGHT, false, 100)
    @font = Gosu::Font.new(self, Gosu.default_font_name, 50)
    self.caption = TITLE
    new_game
  end

  def new_game
    @map = Map.new(MAP_WIDTH, MAP_HEIGHT)
    @snake = Mamba.new(MAP_WIDTH, MAP_HEIGHT)
    update_snake
    new_rabbit
  end

  def new_rabbit
    @rabbit = Rabbit.new(rand(MAP_WIDTH + 1), rand(MAP_HEIGHT + 1))
  end

  def update_rabbit
    @rabbit.update
  end

  def update_snake
    @map[*@snake.update] = :empty
    @snake.parts[1..-1].each { |x, y| @map[x, y] = :snake }
  end

  def update
    return if @paused

    update_snake
    update_rabbit

    if (@map[*@snake.head] == :border) || (@map[*@snake.head] == :snake)
      @paused = true
      new_game
    end

    if @snake.head == @rabbit.pos
      @snake.grow
      while @snake.parts.index(@rabbit.pos)
        new_rabbit
      end
    end
  end

  def draw
    draw_border
    draw_background
    draw_animal(@rabbit.pos, @rabbit.color, Z::Rabbit)
    @snake.parts.each { |part| draw_animal(part, @snake.color, Z::Snake) }
  end

  def draw_border
    draw_quad(0, 0, BORDER_COLOR,
              SCREEN_WIDTH, 0, BORDER_COLOR,
              0, SCREEN_HEIGHT, BORDER_COLOR,
              SCREEN_WIDTH, SCREEN_HEIGHT, BORDER_COLOR,
              Z::Border)
  end

  def draw_background
    draw_quad(10,     10,      TOP_COLOR,
              SCREEN_WIDTH - 10, 10,      TOP_COLOR,
              10,     SCREEN_HEIGHT - 10, BOTTOM_COLOR,
              SCREEN_WIDTH - 10, SCREEN_HEIGHT - 10, BOTTOM_COLOR,
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

