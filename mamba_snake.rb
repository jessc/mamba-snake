#!/usr/bin/env ruby

# 2013-05
# Jesse Cummins
# https://github.com/jessc
# with advice from Ryan Metzler

=begin
# Bug List:

- Just keep throwing yourself at the problem!

# TODO:
- two player game
 - first change snake to player1, then if player2 draw as well
 - the game will definitely have a different flow if it's two player,
     how should that be done?
 - should maintain a "kills" variable if two_player, when players kill each other
- play against a snake AI
- rabbits can breed when near each other, grow old and die
- could go up trees to go to a new level, hunt for birds
- rabbits could exhibit swarm behavior (or a different animal that exhibits this)

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
  attr_accessor :rabbits_eaten, :highscore, :kills

  DIRECTION = { Gosu::KbW    => [0, -1],
                Gosu::KbS  => [0, 1],
                Gosu::KbA  => [-1, 0],
                Gosu::KbD => [1, 0],
                Gosu::KbUp    => [0, -1],
                Gosu::KbDown  => [0, 1],
                Gosu::KbLeft  => [-1, 0],
                Gosu::KbRight => [1, 0] }

  def initialize(map_width, map_height, start_size, grow_length)
    @dir = Gosu::KbUp
    @start_size = start_size
    @grow_length = grow_length

    @body = []
    (0..@start_size).each do |n|
      @body << [(map_width / 2), (map_height / 2)]
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
    Border, Background, Text, Snake, Rabbit = *1..100
  end

  config = YAML.load_file 'config.yaml'

  TITLE = 'Hungry Mamba!'
  WINDOW_WIDTH = config['window_width']
  WINDOW_HEIGHT = config['window_height']
  TILE_WIDTH = config['tile_width']
  MAP_WIDTH = WINDOW_WIDTH / TILE_WIDTH
  MAP_HEIGHT = WINDOW_HEIGHT / TILE_WIDTH

  COLORS = {BLACK: 0xff000000, GRAY: 0xff808080,   WHITE: 0xffffffff,
            AQUA: 0xff00ffff,  RED: 0xffff0000,    GREEN: 0xff00ff00,
            BLUE: 0xff0000ff,  YELLOW: 0xffffff00, FUCHSIA: 0xffff00ff,
            CYAN: 0xff00ffff}

  find_color = ->(color) { COLORS[config[color].upcase.to_sym] }
  set_color  = ->(color) { Gosu::Color.argb(color) }

  TOP_COLOR    = set_color.(find_color.('map_color'))
  BOTTOM_COLOR = set_color.(find_color.('map_color'))
  BORDER_COLOR = set_color.(find_color.('border_color'))
  TEXT_COLOR   = set_color.(find_color.('text_color'))

  RABBIT_COLOR = set_color.(find_color.('rabbit_color'))
  P1_SNAKE_COLOR = set_color.(find_color.('player1_snake_color'))
  P2_SNAKE_COLOR = set_color.(find_color.('player2_snake_color'))
  GAME_SPEED = config['game_speed']
  SNAKE_START_SIZE = config['snake_start_size']
  SNAKE_GROW_LENGTH = config['snake_grow_length']
  RABBIT_HOP_DISTANCE = config['rabbit_hop_distance']
  NUM_OF_RABBITS = config['num_of_rabbits']
  TWO_PLAYER = config['two_player']


  def initialize
    super(WINDOW_WIDTH, WINDOW_HEIGHT, false, GAME_SPEED)
    @font = Gosu::Font.new(self, Gosu.default_font_name, 20)
    @paused = false
    @p1_highscore = 0
    @p1_kills = 0
    @p2_highscore = 0 if TWO_PLAYER
    @p2_kills = 0 if TWO_PLAYER
    self.caption = TITLE
    new_game
  end

  def new_game
    @time = 0
    @p1_dead = false unless @paused
    @map = Map.new(MAP_WIDTH, MAP_HEIGHT)
    unless TWO_PLAYER
      @p1 = Mamba.new(MAP_WIDTH, MAP_HEIGHT, SNAKE_START_SIZE, SNAKE_GROW_LENGTH)  
    else
      @p1 = Mamba.new(MAP_WIDTH / 2, MAP_HEIGHT, SNAKE_START_SIZE, SNAKE_GROW_LENGTH)
      @p2 = Mamba.new((MAP_WIDTH / 2) * 3, MAP_HEIGHT, SNAKE_START_SIZE, SNAKE_GROW_LENGTH)
    end
    @p1.rabbits_eaten = 0
    @p2.rabbits_eaten = 0 if TWO_PLAYER
    @rabbits = []
    NUM_OF_RABBITS.times { new_rabbit }
    update_snake
  end

  def new_rabbit
    x, y = rand(MAP_WIDTH - 1), rand(MAP_HEIGHT - 1)
    if @map[x, y] == :empty
      @map[x, y] = :rabbit
      @rabbits << Rabbit.new(x, y, RABBIT_HOP_DISTANCE)
    else
      new_rabbit
    end
  end

  def update_rabbits
    @rabbits.each do |rabbit|
      x, y = rabbit.next_hop(*rabbit.pos)
      if @map[x, y] == :empty
        rabbit.pos = [x, y]
      else
        rabbit.new_direction
      end
      rabbit.distance -= 1
    end
  end

  def update_snake
    @map[*@p1.update] = :empty
    @p1.body[1..-1].each { |x, y| @map[x, y] = :p1 }
    if TWO_PLAYER
      @map[*@p2.update] = :empty
      @p2.body[1..-1].each { |x, y| @map[x, y] = :p2 }
    end
  end

  def snake_collide?(snake)
    snake_labels = [:p1, :p2]
    (@map[*snake.head] == :border) ||
      snake_labels.include?(@map[*snake.head])
  end

  def snakes_eating_rabbits
    unless TWO_PLAYER
      snakes_eating = [@p1]
    else
      snakes_eating = [@p1, @p2]
    end

    snakes_eating.each do |snake|
      @rabbits.each do |rabbit|
        if snake.head == rabbit.pos
          snake.rabbits_eaten += 1
          if snake.rabbits_eaten > @p1_highscore
            @p1_highscore += 1
          end
          @rabbits.delete(rabbit)
          new_rabbit
          snake.grow
        end
      end
    end
  end

  def snake_kill?(snake1, snake2)
    snake1.body.each do |part|
      if snake2.head == part
        return true
      end
    end
  end

  def update
    return if @paused
    @p1_dead = false
    @time += 1

    snakes_eating_rabbits
    update_snake
    update_rabbits

    if TWO_PLAYER
      if snake_kill?(@p1, @p2)
        @p1_kills += 1
      elsif snake_kill?(@p2, @p1)
        @p2_kills += 1
      end
    end

    if snake_collide? @p1
      @p1_dead = true
      @paused = true
      new_game
      if TWO_PLAYER
        if snake_collide? @p2
          @p2_dead = true
          @paused = true
          new_game
        end
      end
    end
  end

  def reset_score
    @p1_highscore = 0
    @p2_highscore = 0 if TWO_PLAYER
  end

  def draw
    draw_border
    draw_background

    draw_top_text
    draw_player_died("One") if @p1_dead
    draw_bottom_text

    if TWO_PLAYER
      draw_2p_top_text
      draw_player_died # @player # say which player
    end

    @rabbits.each  { |rabbit| draw_animal(rabbit.pos, RABBIT_COLOR, Z::Rabbit) }

    @p1.body.each { |part| draw_animal(part, P1_SNAKE_COLOR, Z::Snake) }
    if TWO_PLAYER
      @p2.body.each { |part| draw_animal(part, P2_SNAKE_COLOR, Z::Snake) }
    end
  end

  def draw_border
    draw_quad(0, 0, BORDER_COLOR,
              WINDOW_WIDTH, 0, BORDER_COLOR,
              0, WINDOW_HEIGHT, BORDER_COLOR,
              WINDOW_WIDTH, WINDOW_HEIGHT, BORDER_COLOR,
              Z::Border)
  end

  def draw_background
    draw_quad(TILE_WIDTH,                TILE_WIDTH,      TOP_COLOR,
              WINDOW_WIDTH - TILE_WIDTH, TILE_WIDTH,      TOP_COLOR,
              TILE_WIDTH,                WINDOW_HEIGHT - TILE_WIDTH, BOTTOM_COLOR,
              WINDOW_WIDTH - TILE_WIDTH, WINDOW_HEIGHT - TILE_WIDTH, BOTTOM_COLOR,
              Z::Background)
  end

  def draw_top_text
    draw_text("Time: #{@time}", TILE_WIDTH, TILE_WIDTH*1)
    draw_text("Player One", TILE_WIDTH, TILE_WIDTH*3)
    draw_text("High Score: #{@p1_highscore}", TILE_WIDTH, TILE_WIDTH*4)
    draw_text("Length: #{@p1.body.length}", TILE_WIDTH, TILE_WIDTH*5)
    draw_text("Rabbits Eaten: #{@p1.rabbits_eaten}", TILE_WIDTH, TILE_WIDTH*6)
    if TWO_PLAYER
      draw_text("Kills: #{@p1_kills}", TILE_WIDTH, TILE_WIDTH*7)
    end
  end

  def draw_bottom_text
    draw_text("P1 Move: Arrows", TILE_WIDTH, TILE_WIDTH*18)
    draw_text("P2 Move: WASD", TILE_WIDTH, TILE_WIDTH*19)
    draw_text("Un/pause: Space", TILE_WIDTH, TILE_WIDTH*20)
    draw_text("Reset Score: R", TILE_WIDTH, TILE_WIDTH*21)
    draw_text("Quit: Esc or Cmd+Q", TILE_WIDTH, TILE_WIDTH*22)
  end

  def draw_2p_top_text
    draw_text("Player Two", TILE_WIDTH, TILE_WIDTH*9)
    draw_text("High Score: #{@p2_highscore}", TILE_WIDTH, TILE_WIDTH*10)
    draw_text("Length: #{@p2.body.length}", TILE_WIDTH, TILE_WIDTH*11)
    draw_text("Rabbits Eaten: #{@p2.rabbits_eaten}", TILE_WIDTH, TILE_WIDTH*12)
    draw_text("Kills: #{@p2_kills}", TILE_WIDTH, TILE_WIDTH*13)
  end

  def draw_player_died(player)
    draw_text("Player #{player} died! Press space.", TILE_WIDTH*11, TILE_WIDTH*5)
  end

  def draw_text(text, x, y)
    @font.draw(text, x, y, Z::Text, 1.0, 1.0, TEXT_COLOR)
  end

  def draw_animal(place, color, layer)
    draw_quad(place[0] * TILE_WIDTH,              place[1] * TILE_WIDTH, color,
              place[0] * TILE_WIDTH + TILE_WIDTH, place[1] * TILE_WIDTH, color,
              place[0] * TILE_WIDTH,              place[1] * TILE_WIDTH + TILE_WIDTH, color,
              place[0] * TILE_WIDTH + TILE_WIDTH, place[1] * TILE_WIDTH + TILE_WIDTH, color,
              layer)
  end

  def button_down(id)
    case id
    when Gosu::KbSpace  then @paused = !@paused
    when Gosu::KbEscape then close
    # why isn't this starting a new_game ?
    when Gosu::KbR      then reset_score && new_game
    when Gosu::KbE      then @map.display
    end

    close if (button_down?(Gosu::KbLeftMeta) && button_down?(Gosu::KbQ))
    close if (button_down?(Gosu::KbRightMeta) && button_down?(Gosu::KbQ))

    @p1.button_down(id)
  end
end


MambaSnakeGame.new.show

