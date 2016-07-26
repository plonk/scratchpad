require 'toml'
require 'gtk2'

require_relative 'interpolator'

class Array
  def x
    self[0]
  end

  def x=(v)
    self[0] = v
  end

  def y
    self[1]
  end

  def y=(v)
    self[1] = v
  end
end

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

class SheetModel < GLib::Object
  type_register
  signal_new('changed', GLib::Signal::ACTION, nil, nil)

  attr_reader :points

  def initialize
    super()
    @pen_down = false
    @points = []
  end

  def pen_down(ev)
    @points = []
    @points << [ev.x, ev.y]
    @pen_down = true
  end

  def pen_up(ev)
    @pen_down = false
  end

  def pen_move(ev)
    if @pen_down
      points << [ev.x, ev.y]
      signal_emit('changed')
    end
  end
end

class SheetView < Gtk::DrawingArea
  include Math
  include Cairo

  def initialize()
    super()
    self.app_paintable = true

    @surface = ImageSurface.new(Cairo::FORMAT_ARGB32, 800, 600)
    @debug_surface = ImageSurface.new(Cairo::FORMAT_ARGB32, 800, 600)

    set_size_request(800, 600)
    signal_connect('expose-event') do
      draw
    end

    signal_connect('motion-notify-event') do |self_, ev|
      @model.pen_move(ev)
    end

    signal_connect('button-press-event') do |self_, ev|
      @model.pen_down(ev)
    end

    signal_connect('button-release-event') do |self_, ev|
      @model.pen_up(ev)
    end

    @model = SheetModel.new
    @model.signal_connect('changed') do
      invalidate
    end

#    @model.points.replace([[200, 100], [600, 100], [600, 500], [200, 500], [200, 100]])

    self.events |= Gdk::Event::BUTTON_PRESS_MASK |
                   Gdk::Event::BUTTON_RELEASE_MASK |
                   # Gdk::Event::POINTER_MOTION_HINT_MASK |
                   Gdk::Event::POINTER_MOTION_MASK

  end

  def clear
    cr = Context.new(@surface)
    cr.set_operator(Cairo::OPERATOR_SOURCE)
    cr.set_source_rgba(0, 0, 0, 0)
    cr.paint
    cr.destroy
    clear_debug
  end

  def clear_debug
    cr = Context.new(@debug_surface)
    cr.set_operator(Cairo::OPERATOR_SOURCE)
    cr.set_source_rgba(0, 0, 0, 0)
    cr.paint
    cr.destroy
  end

  def differences(points)
    points.each_cons(2).map { |p1, p2|
      [p2.x - p1.x, p2.y - p1.y]
    }
  end

  def tangents(vs)
    return [] if vs.empty?

    first = vs[0]
    last = vs[-1]

    [first, *vs, last].each_cons(2).map { |v1, v2|
      normalize [(v1.x + v2.x) * 0.5, (v1.y + v2.y) * 0.5]
    }
  end

  def normalize(v)
    magnitude = sqrt(v.x ** 2 + v.y ** 2)
    [v.x / magnitude, v.y / magnitude]
  end

  def draw_on_surface
    clear
    cr = Context.new(@surface)
    vs = differences(@model.points)
    @model.points[0..-2].each.with_index do |point, i|
      cr.move_to(point.x, point.y)
      cr.rel_line_to(vs[i].x, vs[i].y)
      cr.stroke
    end

    ts = tangents(vs)

    @model.points.each.with_index do |point, i|
      cr.set_source_rgba(rand, rand, rand)
      cr.line_width = 3
      cr.move_to(point.x + ts[i].x * 40, point.y + ts[i].y * 40)
      # cr.rel_line_to(ts[i].x * 10, ts[i].y * 10)
      # cr.stroke
      # cr.move_to(point.x, point.y)
      cr.rel_line_to(-ts[i].x * 80, -ts[i].y * 80)
      cr.stroke
    end

    # @model.points.each do |point|
    #   cr.set_source_rgba(0, 0, 0)
    #   cr.arc(point.x, point.y, 3, 0, Math::PI*2)
    #   cr.fill
    # end

  ensure
    cr.destroy
  end

  def draw
    draw_on_surface

    cr = window.create_cairo_context

    cr.set_source(@surface)
    cr.paint
    cr.set_source(@debug_surface)
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

  def setup_window
    win = Window.new
    vbox = VBox.new
    hbox = HBox.new
    a = Button.new('A')
    b = Button.new('B')
    c = Button.new('C')
    hbox.pack_start(a)
    hbox.pack_start(b)
    hbox.pack_start(c)
    vbox.pack_start(hbox)
    sheet = SheetView.new
    vbox.pack_start(sheet)
    win.add vbox
    win.show_all
  end

  def run
    setup_window

    until @quit_requested
      Gtk.main_iteration while Gtk.events_pending?
    end
  end
end

if $0 == __FILE__
  Program.new.run
end
