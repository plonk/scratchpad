module Scrachpad

class Interpolator
  include Math

  class DataPoint < Struct.new(:v, :pos)
  end

  def initialize
    @x_v = nil
    @y_v = nil
    @x          = nil
    @y          = nil
    @ring = [nil, nil, nil]
  end

  X = 0
  Y = 1

  # (x, y) -> [[Float, Float, Float]]
  def feed(x, y, is_down)
    raise unless @ring.size == 3

    @ring.shift
    @ring << [DataPoint.new(nil, x), DataPoint.new(nil, y), is_down]

    if @ring[1] == nil
      # cannot calculate yet
      return []
    else
      # calculate @ring[1]'s velocity
      if @ring[0] == nil
        @ring[1][X].v = (@ring[2][X].pos - @ring[1][X].pos)
        @ring[1][Y].v = (@ring[2][Y].pos - @ring[1][Y].pos)
        return []
      else
        @ring[1][X].v = ((@ring[1][X].pos - @ring[0][X].pos) + (@ring[2][X].pos - @ring[1][X].pos)) * 0.5
        @ring[1][Y].v = ((@ring[1][Y].pos - @ring[0][Y].pos) + (@ring[2][Y].pos - @ring[1][Y].pos)) * 0.5
        # unless @ring[1][2] # is_down
        #   return []
        # else
          return interpolate
#        end
      end
    end
  end

  # interpolate using @ring[0] and @ring[1]
  def interpolate
    a, b = find_accelerations(@ring[0][X].pos,
                                @ring[0][X].v,
                                @ring[1][X].pos,
                                @ring[1][X].v)
    s = @ring[0][X].pos
    velocity = @ring[0][X].v
    xpoints = (0..10).map { |n| n*0.1 }.map do |t|
      [s, velocity].tap do
        s += 0.1 * velocity 
        if t < 0.5
          velocity += a * 0.1
        else
          velocity += b * 0.1
        end
      end
    end

    a, b = find_accelerations(@ring[0][Y].pos,
                                @ring[0][Y].v,
                                @ring[1][Y].pos,
                                @ring[1][Y].v)
    s = @ring[0][Y].pos
    velocity = @ring[0][Y].v
    ypoints = (0..10).map { |n| n*0.1 }.map do |t|
      [s, velocity].tap do
        s += 0.1 * velocity 
        if t < 0.5
          velocity += a * 0.1
        else
          velocity += b * 0.1
        end
      end
    end

    return xpoints.zip(ypoints).map { |x_data, y_data|
      [x_data[0], y_data[0], sqrt(x_data[1] ** 2 + y_data[1] ** 2)]
    }
  end

  def find_accelerations(s, velocity, target_position, target_velocity)
    a = 0.0
    b = 0.0

    s_ = s
    velocity_ = velocity

    loop do
      s = s_
      velocity = velocity_

      (0..9).map { |n| n*0.1 }.map do |t|
        [t, s].tap do
          s += 0.1 * velocity
          if t < 0.5
            velocity += a * 0.1
          else
            velocity += b * 0.1
          end
        end
      end

      if (s - target_position).abs >= 0.001
        a += -(s - target_position) * 1.0
      elsif (velocity - target_velocity).abs >= 0.001
        b += -(velocity - target_velocity) * 1.0
      else
        return a, b
      end
    end
  end

end

if __FILE__ == $0
  obj = Interpolator.new
  p obj.feed(0.0, 0.0)
  p obj.feed(1.0, 1.0)
  p obj.feed(2.0, 2.0)
  p obj.feed(5.0, 5.0)
  p obj.feed(0.0, 0.0)
end

end
