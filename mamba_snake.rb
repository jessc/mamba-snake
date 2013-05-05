#!/usr/bin/env ruby

# 2013-05
# Jesse Cummins
# https://github.com/jessc
# with advice from Ryan Metzler

=begin
# Bug List / TODO:

- Just keep throwing yourself at the problem!
- sometimes the snake will not eat the rabbit,
  as if the rabbit has jumped away,
  which leads to the rabbit on top of the snake
- when game starts, if a different direction that :right is chosen,
  snake stretches weirdly (press up-right quickly)
- if direction keys are pressed rapidly the snake can run on top
  of itself and instantly die
- see if you can factor out the case...whens
- sometimes no rabbit appears when the game starts, perhaps also when it's eaten

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
- speed up snake with key presses or as it gets longer


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
  attr_accessor :pos, :distance
  def initialize(x, y)
    @color = Gosu::Color::WHITE
    @dir = :right
    @default = 5
    @distance = @default
    @pos = [x, y]
  end

  def dir_x
    case @dir
    when :left  then -1
    when :right then 1
    else 0
    end
  end

  def dir_y
    case @dir
    when :up    then -1
    when :down  then 1
    else 0
    end
  end

  def new_direction
    @dir = [:left, :right, :up, :down].sample
  end

  def next_hop(x, y)
    next_pos = [x, y]
    if @distance >= 1
      next_pos[0] += dir_x
      next_pos[1] += dir_y
    else
      @distance = @default
      new_direction
    end
    next_pos
  end
end


class Mamba
  attr_reader :color, :head, :parts, :dir
  def initialize(map_width, map_height)
    @color = Gosu::Color::BLACK
    @dir = :right
    @grow_length = 5
    @start_size = 5

    @parts = []
    (0..@start_size).each do |n|
      @parts << [(map_width / 2) - n, (map_height / 2)]
    end
    @head = @parts.pop
  end

  def dir_x
    case @dir
    when :left  then -1
    when :right then 1
    else 0
    end
  end

  def dir_y
    case @dir
    when :up    then -1
    when :down  then 1
    else 0
    end
  end

  def update
    @head[0] += dir_x
    @head[1] += dir_y

    @parts.unshift [@head[0], @head[1]]
    @parts.pop
  end

  def grow
    @grow_length.times { @parts << @parts[-1] }
  end

  def direction(id)
    @dir = case id
                 when Gosu::KbRight then @dir == :left  ? @dir : :right
                 when Gosu::KbUp    then @dir == :down  ? @dir : :up
                 when Gosu::KbLeft  then @dir == :right ? @dir : :left
                 when Gosu::KbDown  then @dir == :up    ? @dir : :down
                 else @dir
                 end
  end
end


class MambaSnakeGame < Gosu::Window
  module Z
    Border, Background, Map, Text, Snake, Rabbit = *1..100
  end

  settings = YAML.load_file 'config.yaml'

  MAP_WIDTH = settings['map_width']
  MAP_HEIGHT = settings['map_height']
  SCREEN_WIDTH = settings['screen_width']
  SCREEN_HEIGHT = settings['screen_height']

  TITLE = 'Hungry Mamba!'
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
    x, y = rand(MAP_WIDTH + 1), rand(MAP_HEIGHT + 1)
    if @map[x, y] == :empty
      @map[x, y] = :rabbit
      @rabbit = Rabbit.new(x, y)
    else
      new_rabbit
    end
  end

  def update_rabbit
    x, y = @rabbit.next_hop(*@rabbit.pos)
    if @map[x, y] == :empty
      @rabbit.pos = [x, y]
    else
      @rabbit.new_direction
    end
    @rabbit.distance -= 1
  end

  def update_snake
    @map[*@snake.update] = :empty
    @snake.parts[1..-1].each { |x, y| @map[x, y] = :snake }
  end

  def snake_collide?
    (@map[*@snake.head] == :border) || (@map[*@snake.head] == :snake)
  end

  def update
    return if @paused

    update_snake
    if @snake.head == @rabbit.pos
      @snake.grow
      new_rabbit
    end
    update_rabbit

    if snake_collide?
      @paused = true
      new_game
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
    draw_quad(place[0] * 10, place[1] * 10, color,
              place[0] * 10 + 10, place[1] * 10, color,
              place[0] * 10, place[1] * 10 + 10, color,
              place[0] * 10 + 10, place[1] * 10 + 10, color,
              layer)
  end

  def button_down(id)
    case id
    when Gosu::KbSpace  then @paused = !@paused
    when Gosu::KbEscape then close
    when Gosu::KbR      then new_game
    when Gosu::KbE      then @map.display
    end

    close if (button_down?(Gosu::KbLeftMeta) && button_down?(Gosu::KbQ))
    close if (button_down?(Gosu::KbRightMeta) && button_down?(Gosu::KbQ))

    @snake.direction(id)
  end
end


MambaSnakeGame.new.show

