class Point
  attr_accessor :longitude, :latitude

  def initialize params
    @latitude = params[:lat] if !params[:lat].nil?
    @longitude = params[:lng] if !params[:lng].nil?

    if(!params[:type].nil? and params[:type] == "Point")
      @latitude = params[:coordinates][1]
      @longitude = params[:coordinates][0]
    end
  end

  def to_hash
    { type: "Point", coordinates: [@longitude, @latitude]}
  end
end