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
# /便利関数

class Pen
  include Math

  attr_reader :x, :y

  FAVORITE_ORANGE = [255.0/255.0, 109/255.0, 50/255.0]

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
    1.0
  end

  def color
    FAVORITE_ORANGE
  end
end

class SheetModel < GLib::Object
  type_register
  signal_new('changed', GLib::Signal::ACTION, nil, nil)
  
  include Math
  include Cairo

  attr_reader :surface, :pen

  def initialize
    super()
    @surface = ImageSurface.new(Cairo::FORMAT_ARGB32, 800, 600)
    cr = Context.new(@surface)
    cr.set_operator(Cairo::OPERATOR_OVER)
    @context = cr

    @pen = Pen.new
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
    signal_emit('changed')
  end

  def pen_down(ev)
    update
    @pen.down(ev)

    # cr.set_source_rgba([0, 0, 1])
    # cr.rectangle(ev.x, ev.y, 1, 1)
    # cr.fill
  end

  def pen_up(ev)
    @pen.up(ev)
    update
  end

  def normalize(ary)
    sum = ary.max
    ary.map { |x| x / sum }
  end

  def update
    if @pen.down?
      @pen.path.each do |x, y, radius|
        r, g, b = @pen.color
        # p [r, radius, b]
        cr.set_source_rgba(r, g, b)
        # p [x, y]
        cr.arc(x, y, @pen.radius, 0, 2*PI)
        cr.fill
      end
    end
    signal_emit('changed')
  end

  def pen_move(ev)
    @pen.move(ev)
    update

    # if @pen.down?
    #   cr.set_source_rgba([0, 0, 1])
    #   cr.rectangle(ev.x, ev.y, 1, 1)
    #   cr.fill
    # end
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
    end
    last_point = nil
    signal_connect('motion-notify-event') do |self_, ev|
      if last_point == nil
        last_point = [ev.x, ev.y]
        @model.pen_move(ev)
      else
        last_point = midpoint(last_point, [ev.x, ev.y])
        ev.x, ev.y = last_point
        @model.pen_move(ev)
      end
    end
    signal_connect('button-press-event') do |self_, ev|
      if ev.button == 1
        @model.pen_down(ev)
      elsif ev.button == 3
        @model.clear
      end
    end
    signal_connect('button-release-event') do |self_, ev|
      if ev.button == 1
        @model.pen_move(ev)
        @model.pen_up(ev)
      end
    end

    @model = SheetModel.new
    @model.signal_connect('changed') do
      invalidate
    end

    self.events |= Gdk::Event::BUTTON_PRESS_MASK |
                   Gdk::Event::BUTTON_RELEASE_MASK |
                   # Gdk::Event::POINTER_MOTION_HINT_MASK |
                   Gdk::Event::POINTER_MOTION_MASK

  end

  def draw
    cr = window.create_cairo_context

    cr.set_source(@model.surface)
    cr.paint

    cr.destroy
  end

  def invalidate
    window.invalidate(window.clip_region, true)
    window.process_updates(true)
  end     
end

class Program
  include Gtk

  def initialize
    @quit_requested = false

    Signal.trap(:INT) {
      STDERR.puts("Interrupted")
      @quit_requested = true
    }
  end

  def quit
    @quit_requested = true
  end

  def run
    win = Window.new
    sheet = SheetView.new
    win.add sheet
    win.show_all

    until @quit_requested
      Gtk.main_iteration while Gtk.events_pending?
    end
  end
end

if $0 == __FILE__
  Program.new.run
end
