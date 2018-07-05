class Photo
  require 'exifr/jpeg'
  include Mongoid::Document
  include ActiveModel::Model

  belongs_to :place

  attr_accessor :id, :location, :contents

  def self.mongo_client
    return Mongoid::Clients.default
  end

  def contents
    f = mongo_client.database.fs.find_one(_id: BSON::ObjectId.from_string(@id))

    if f
      buffer = ""
      f.chunks.reduce([]) do |x, y|
        buffer << y.data.data
      end
      return buffer
    end
  end

  def initialize(params = {})
    if !params.nil?
      @id = params[:_id].nil? ? params[:id] : params[:_id].to_s
      @place = params[:metadata].nil? ? nil : params[:metadata][:place].to_s
      @location = Point.new(params[:metadata][:location]) if !params[:metadata].nil?
    else
      Photo.new
    end
  end

  def self.all(skip = 0, limit = nil)
    res = mongo_client.database.fs.find.skip(skip)
    res = res.limit(limit) if !limit.nil?
    res.map {|doc| Photo.new(doc)}
  end

  def self.find id
    photo = mongo_client.database.fs.find({_id: BSON::ObjectId.from_string(id)}).first
    return photo.nil? ? photo : Photo.new(photo)
  end

  def self.find_photos_for_place id
    id = BSON::ObjectId.from_string(id.to_s)
    self.mongo_client.database.fs.find("metadata.place": id)
  end

  def destroy
    mongo_client.database.fs.find(_id: BSON::ObjectId.from_string(@id)).delete_one
  end

  def find_nearest_place_id  max
    places = Place.near(@location,max).limit(1).projection(_id: 1).map {|doc| doc[:_id]}[0]
    return places.nil? ? nil : BSON::ObjectId.from_string(places)
  end

  def persisted?
    !@id.nil?
  end

  def save
    if persisted?
      update = {metadata: {location: @location.to_hash, place: @place}}
      self.class.mongo_client.database.fs.find(_id: BSON::ObjectId(@id.to_s)).update_one(update)
    else
      position = EXIFR::JPEG.new(@contents).gps
      @contents.rewind
      @location = Point.new(lat: position.latitude, lng: position.longitude)
      des = { filename: @contents.to_s,
              content_type: "image/jpeg",
              metadata: {location: @location.to_hash}}
      des[:metadata][:place] = BSON::ObjectId.from_string(@place.id.to_s) if !@place.nil?
      if @contents
        grid_file = Mongo::Grid::File.new(@contents.read, des)
        @id = self.class.mongo_client.database.fs.insert_one(grid_file).to_s
      end
    end
    @id
  end

  def place
    if @place != ''
      return Place.find(@place.to_s)
    end
  end

  def place= p
    if p.class == String
      @place = BSON::ObjectId.from_string(p)
    else
      if p.class == Place
        @place = BSON::ObjectId(p.id.to_s)
      else
        @place = p
      end
    end
  end

end