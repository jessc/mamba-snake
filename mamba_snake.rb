#!/usr/bin/env ruby

# 2013-05
# Jesse Cummins
# https://github.com/jessc
# with advice from Ryan Metzler

=begin
# Bug List:

- Just keep throwing yourself at the problem!
- when game starts, if a different direction that :right is chosen,
    snake stretches weirdly (press up-right quickly)
    - as if the head is not at the furthest right but is in the middle
        of the snake
- kind of has a glitchy feel where the snake "jumps" ahead,
    right before it catches the rabbit
- rabbit may still be able to respawn on the head of the snake?
- snake doesn't immediately start moving at beginning of game
    - I think it's because it's taking two steps to replace the white rabbit
        with the black snake
    - it looks like the head is at the end of the snake, rather than the start
- config snake start pos
- overlay "You died!\nPress Space to restart." when the game resets

# TODO:
- add timer
- add instructions at top of screen
- allow for multiple rabbits
- add highscore
- multiplayer game
- play against a snake AI
- rabbits can breed when near each other, grow old and die
- could go up trees to go to a new level, hunt for birds
- snake could move diagonally
- rabbits could exhibit swarm behavior
- speed up snake with key presses or as it gets longer
- snake could have boosts when you press a button to go faster

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
  attr_accessor :pos, :distance

  DIRECTION = { up:    [0, -1],
                down:  [0, 1],
                left:  [-1, 0],
                right: [1, 0] }

  def initialize(x, y, distance)
    @dir = :right
    @default = distance
    @distance = @default
    @pos = [x, y]
  end

  def new_direction
    @dir = [:left, :right, :up, :down].sample
  end

  def next_hop(x, y)
    next_pos = [x, y]
    if @distance >= 1
      next_pos[0] += DIRECTION[@dir][0]
      next_pos[1] += DIRECTION[@dir][1]
    else
      @distance = @default
      new_direction
    end
    next_pos
  end
end


class Mamba
  attr_reader :head, :body, :dir
  attr_accessor :status

  DIRECTION = { Gosu::KbUp    => [0, -1],
                Gosu::KbDown  => [0, 1],
                Gosu::KbLeft  => [-1, 0],
                Gosu::KbRight => [1, 0] }

  def initialize(map_width, map_height, start_size, grow_length)
    @dir = Gosu::KbRight
    @start_size = start_size
    @grow_length = grow_length
    @status = :alive

    @body = []
    (0..@start_size).each do |n|
      @body << [(map_width / 2) - n, (map_height / 2)]
    end
    @head = @body.pop
  end

  def update
    @head[0] += DIRECTION[@dir][0]
    @head[1] += DIRECTION[@dir][1]

    @body.unshift [@head[0], @head[1]]
    @body.pop
  end

  def grow
    @grow_length.times { @body << @body[-1] }
  end

  def button_down(id)
    if DIRECTION.keys.include?(id)
      next_head = [@head[0] + DIRECTION[id][0],
                   @head[1] + DIRECTION[id][1]]
      unless @body.include?(next_head)
        @dir = id
      end
    end
  end
end


class MambaSnakeGame < Gosu::Window
  module Z
    Border, Background, Map, Text, Snake, Rabbit = *1..100
  end

  config = YAML.load_file 'config.yaml'

  TITLE = 'Hungry Mamba!'

  WINDOW_WIDTH = config['window_width']
  WINDOW_HEIGHT = config['window_height']
  TILE_WIDTH = config['tile_width']
  MAP_WIDTH = WINDOW_WIDTH / TILE_WIDTH
  MAP_HEIGHT = WINDOW_HEIGHT / TILE_WIDTH

  COLORS = {BLACK: 0xff000000, GRAY: 0xff808080, WHITE: 0xffffffff,
            AQUA: 0xff00ffff, RED: 0xffff0000, GREEN: 0xff00ff00,
            BLUE: 0xff0000ff, YELLOW: 0xffffff00, FUCHSIA: 0xffff00ff,
            CYAN: 0xff00ffff}

  find_color = ->(color) { COLORS[config[color].upcase.to_sym] }
  set_color = -> (color) { Gosu::Color.argb(color) }

  TOP_COLOR    = set_color.(find_color.('map_color'))
  BOTTOM_COLOR = set_color.(find_color.('map_color'))
  TEXT_COLOR   = set_color.(find_color.('text_color'))
  BORDER_COLOR = set_color.(find_color.('border_color'))
  SNAKE_COLOR  = set_color.(find_color.('snake_color'))
  RABBIT_COLOR = set_color.(find_color.('rabbit_color'))

  SNAKE_START_SIZE = config['snake_start_size']
  SNAKE_GROW_LENGTH = config['snake_grow_length']

  RABBIT_HOP_DISTANCE = config['rabbit_hop_distance']

  def initialize
    super(WINDOW_WIDTH, WINDOW_HEIGHT, false, 100)
    @font = Gosu::Font.new(self, Gosu.default_font_name, 20)
    @paused = false
    self.caption = TITLE
    new_game
  end

  def new_game
    @map = Map.new(MAP_WIDTH, MAP_HEIGHT)
    @snake = Mamba.new(MAP_WIDTH, MAP_HEIGHT, SNAKE_START_SIZE, SNAKE_GROW_LENGTH)
    update_snake
    new_rabbit
  end

  def new_rabbit
    x, y = rand(MAP_WIDTH - 1), rand(MAP_HEIGHT - 1)
    if @map[x, y] == :empty
      @map[x, y] = :rabbit
      @rabbit = Rabbit.new(x, y, RABBIT_HOP_DISTANCE)
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
    @snake.body[1..-1].each { |x, y| @map[x, y] = :snake }
    # obviously the head should be :snake, but how to get it to work?
    # maybe if there is a next_head?
  end

  def snake_collide?
    (@map[*@snake.head] == :border) || (@map[*@snake.head] == :snake)
  end

  def update
    return if @paused

    if @snake.head == @rabbit.pos
      @snake.grow
      new_rabbit
    end
    update_snake
    update_rabbit

    if snake_collide?
      @paused = true
      new_game
    end
  end

  def draw
    draw_border
    draw_background
    draw_top_text
    draw_you_died if @snake.status == :dead
    draw_bottom_text
    draw_animal(@rabbit.pos, RABBIT_COLOR, Z::Rabbit)
    @snake.body.each { |part| draw_animal(part, SNAKE_COLOR, Z::Snake) }
  end

  def draw_border
    draw_quad(0, 0, BORDER_COLOR,
              WINDOW_WIDTH, 0, BORDER_COLOR,
              0, WINDOW_HEIGHT, BORDER_COLOR,
              WINDOW_WIDTH, WINDOW_HEIGHT, BORDER_COLOR,
              Z::Border)
  end

  def draw_background
    draw_quad(TILE_WIDTH,     TILE_WIDTH,      TOP_COLOR,
              WINDOW_WIDTH - TILE_WIDTH, TILE_WIDTH,      TOP_COLOR,
              TILE_WIDTH,     WINDOW_HEIGHT - TILE_WIDTH, BOTTOM_COLOR,
              WINDOW_WIDTH - TILE_WIDTH, WINDOW_HEIGHT - TILE_WIDTH, BOTTOM_COLOR,
              Z::Background)
  end

  def draw_top_text
    draw_text("High Score: #{@highscore}", TILE_WIDTH, TILE_WIDTH*1)
    draw_text("Time: #{@time}", TILE_WIDTH, TILE_WIDTH*2)
    draw_text("Length: #{@length}", TILE_WIDTH, TILE_WIDTH*3)
    draw_text("Rabbits Eaten: #{@rabbits_eaten}", TILE_WIDTH, TILE_WIDTH*4)
  end

  def draw_you_died
    text = "You died! Press space."
    text_width = @font.text_width(text)
    draw_text(text, TILE_WIDTH*11, TILE_WIDTH*5)
  end
  
  def draw_bottom_text
    draw_text("Move: Arrow Keys", TILE_WIDTH, TILE_WIDTH*19)
    draw_text("Un/pause: Space", TILE_WIDTH, TILE_WIDTH*20)
    draw_text("Restart: R", TILE_WIDTH, TILE_WIDTH*21)
    draw_text("Quit: Escape or Command+Q", TILE_WIDTH, TILE_WIDTH*22)
  end

  def draw_text(text, x, y)
    @font.draw(text, x, y, Z::Text, 1.0, 1.0, TEXT_COLOR)
  end

  def draw_animal(place, color, layer)
    draw_quad(place[0] * TILE_WIDTH, place[1] * TILE_WIDTH, color,
              place[0] * TILE_WIDTH + TILE_WIDTH, place[1] * TILE_WIDTH, color,
              place[0] * TILE_WIDTH, place[1] * TILE_WIDTH + TILE_WIDTH, color,
              place[0] * TILE_WIDTH + TILE_WIDTH, place[1] * TILE_WIDTH + TILE_WIDTH, color,
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

    @snake.button_down(id)
  end
end


MambaSnakeGame.new.show

