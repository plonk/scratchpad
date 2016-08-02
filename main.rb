require 'toml'
require 'gtk2'

require_relative 'interpolator'


# 便利関数
def distance(p1, p2)
  x1, y1 = p1
  x2, y2 = p2

  return Math.sqrt((x1 - x2)**2 + (y1 - y2)**2)
end

def chess_distance(p1, p2)
  x1, y1 = p1
  x2, y2 = p2

  return [(x1 - x2).abs, (y1 - y2).abs].max
end

def midpoint(p1, p2)
  x1, y1 = p1
  x2, y2 = p2

  return [(x1 + x2) * 0.5, (y1 + y2) * 0.5]
end

def color_bytes_to_floats(bytes)
  raise 'wrong range' unless bytes.all? { |x| x >= 0 && x <= 255 }
  raise 'wrong dimension' unless bytes.size.between?(3, 4)

  return bytes.map { |b| b / 255.0 }
end

# /便利関数

class Pen
  include Math

  attr_reader :x, :y

  FAVORITE_ORANGE = color_bytes_to_floats [255, 109, 50]
  FAVORITE_BLUE = color_bytes_to_floats [0, 3, 126]

  def initialize
    @is_down = false
    @interpolator = Interpolator.new
    @path = []
  end

  # [[x, y, radius]*]
  def path
    f =  proc { |x|
      [-5.0/10.0 * x + 8.0, 0.3].max
      #x
    }
    @path.map { |x, y, velocity|
      [x, y, sqrt(f.(velocity))]
    }
  end

  def down(ev)
    @is_down = true
  end

  def up(ev)
    @is_down = false
  end
  
  def move(ev)
    @path = @interpolator.feed(ev.x, ev.y, @is_down)
  end

  def down?
    @is_down
  end

  def radius
    2.0
  end

  def color
    FAVORITE_BLUE
  end
end

class SheetModel < GLib::Object
  type_register
  signal_new('changed', GLib::Signal::ACTION, nil, nil)
  
  include Math
  include Cairo

  attr_reader :surface, :pen, :debug_surface

  def initialize
    super()
    @surface = ImageSurface.new(Cairo::FORMAT_ARGB32, 1200, 900)
    @debug_surface = ImageSurface.new(Cairo::FORMAT_ARGB32, 1200, 900)
    cr = Context.new(@surface)
    cr.set_operator(Cairo::OPERATOR_OVER)
    cr.line_cap = cr.line_join = :round
    @context = cr

    @pen = Pen.new

    @portion = :all
  end

  def cr
    @context
  end

  def clear
    cr.save do
      cr.set_operator(Cairo::OPERATOR_SOURCE)
      cr.set_source_rgba(0, 0, 0, 0)
      cr.paint
    end
    clear_debug
    signal_emit('changed')
  end

  def clear_debug
    c = Context.new(@debug_surface)
    c.save do
      c.set_operator(Cairo::OPERATOR_SOURCE)
      c.set_source_rgba(0, 0, 0, 0)
      c.paint
    end
    c.destroy
  end

  def pen_down(ev)
    @pen.down(ev)
    @portion = :latter_half
  end

  def pen_up(ev)
    @pen.up(ev)
    @portion = :first_half
  end

  def normalize(ary)
    sum = ary.max
    ary.map { |x| x / sum }
  end

  def update
    if @pen.down?
      case @portion 
      when :all
        path = @pen.path
        cr.set_source_rgba(@pen.color)
        cr.line_width = @pen.radius
        path.each.with_index do |(x, y, radius), i|
          if i == 0
	    cr.move_to(x, y)
	  else
            cr.line_to(x, y)
	  end
        end
        cr.stroke
      when :latter_half
        path = @pen.path[5..10] || []
        cr.set_source_rgba(@pen.color)
        cr.line_width = @pen.radius
        path.each.with_index do |(x, y, radius), i|
	  if i == 0
	    cr.move_to(x, y)
	  else
            # cr.arc(x, y, (i/4.0)*@pen.radius, 0, 2*PI)
            cr.line_to(x, y)
	  end
        end
        cr.stroke
      end
      @portion = :all
    else
      if @portion == :first_half
        path = @pen.path[0..4] || []
        cr.set_source_rgba(@pen.color)
        cr.line_width = @pen.radius
        path.each.with_index do |(x, y, radius), i|
	  if i == 0
	    cr.move_to(x, y)
	  else
            cr.line_to(x, y)
	  end
        end
        cr.stroke
        @portion = :all
      end
    end
    signal_emit('changed')
  end

  def pen_move(ev)
    @pen.move(ev)
    update

    signal_emit('changed')
  end
end

class SheetView < Gtk::DrawingArea
  def initialize()
    super()
    self.app_paintable = true

    set_size_request(800, 600)
    signal_connect('expose-event') do
      draw
      true
    end
    last_point = nil
    signal_connect('motion-notify-event') do |self_, ev|
      ev.x = ev.x + 0.5
      ev.y = ev.y + 0.5

      c = Cairo::Context.new(@model.debug_surface)
        c.set_source_rgba([0, 1, 0])
        c.rectangle(ev.x - 1, ev.y - 1, 2, 2)
        # c.set_source_rgba([0, 0, 1])
        # c.rectangle(ev.x - 2, ev.y - 2, 4, 4)
      c.fill
      c.destroy

      if last_point == nil
        last_point = [ev.x, ev.y]
        @model.pen_move(ev)
      else
        if distance(last_point, [ev.x, ev.y]) < (1.0/0.0)
          last_point = midpoint(last_point, [ev.x, ev.y])
          ev.x, ev.y = last_point
        else
          last_point = [ev.x, ev.y]
        end
        @model.pen_move(ev)
      end
    end
    signal_connect('button-press-event') do |self_, ev|
      c = Cairo::Context.new(@model.debug_surface)
      c.set_source_rgba([1, 0, 0])
      c.rectangle(ev.x - 2, ev.y - 2, 4, 4)
      c.fill
      c.destroy


      if ev.button == 1
        @model.pen_down(ev)
      elsif ev.button == 3
        @model.clear
      end
    end
    signal_connect('button-release-event') do |self_, ev|
      c = Cairo::Context.new(@model.debug_surface)
      c.set_source_rgba([1, 0, 0])
      c.rectangle(ev.x - 2, ev.y - 2, 4, 4)
      c.fill
      c.destroy

      if ev.button == 1
        @model.pen_move(ev)
        @model.pen_up(ev)
      end
    end

    @model = SheetModel.new
    @model.signal_connect('changed') do
      # invalidate
    end

    self.events |= Gdk::Event::BUTTON_PRESS_MASK |
                   Gdk::Event::BUTTON_RELEASE_MASK |
                   # Gdk::Event::POINTER_MOTION_HINT_MASK |
                   Gdk::Event::POINTER_MOTION_MASK

  end

  def draw
    cr = window.create_cairo_context

    cr.set_operator(Cairo::OPERATOR_SOURCE)
    cr.set_source_rgba(1.0, 1.0, 1.0, 0.5)
    cr.paint 

    cr.set_operator(Cairo::OPERATOR_OVER)
    cr.set_source(@model.surface)
    cr.paint
    # cr.set_source(@model.debug_surface)
    # cr.paint

    cr.destroy
  end

  def invalidate
    window.invalidate(window.clip_region, true)
    window.process_updates(true)
  end     
end

class MainWindow < Gtk::Window
  def initialize
    super()

    self.title = "Scratchpad"

    set_rgba_colormap
    signal_connect('screen-changed') do
      set_rgba_colormap
    end
  end

  def set_rgba_colormap
    self.colormap = screen.rgba_colormap || screen.rgb_colormap
  end
end

class Program
  include Gtk

  def initialize
    @quit_requested = false

    Signal.trap(:INT) {
      STDERR.puts("Interrupted")
      Gtk.main_quit
      @quit_requested = true
    }
  end

  def quit
    @quit_requested = true
  end

  def run
    win = MainWindow.new
    win.maximize
    sheet = SheetView.new
    win.add sheet
    win.show_all

    Gtk.timeout_add(33) do
      sheet.invalidate
    end

    # until @quit_requested
    #  Gtk.main_iteration while Gtk.events_pending?
    # end
    Gtk.main
  end
end

if $0 == __FILE__
  Program.new.run
end
