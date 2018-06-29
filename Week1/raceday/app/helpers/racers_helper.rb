module RacersHelper

  def toRacer(data)
    res = data
    res = Racer.new(data) if !data.is_a?(Racer)
    return res
  end
end
