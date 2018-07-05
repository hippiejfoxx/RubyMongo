class Place
  include Mongoid::Document

  attr_accessor :id, :formatted_address, :location, :address_components

  def initialize params
    @id = params[:_id].to_s
    @address_components = params[:address_components].map{|x| AddressComponent.new(x)} if !params[:address_components].nil?
    @formatted_address = params[:formatted_address] if !params[:formatted_address].nil?
    @location = Point.new(params[:geometry][:geolocation])
  end

  def self.mongo_client
    return Mongoid::Clients.default
  end

  def self.load_all(input)
    data = JSON.parse(input.readlines.join(""))
    Place.collection.insert_many(data)
  end

  def self.to_places collection
    collection.map {|doc| Place.new(doc)}
  end

  def self.find id
    id = BSON::ObjectId.from_string(id)
    res = collection.find({_id: id}).first
    res = Place.new(res) if !res.nil?
  end

  def self.find_by_short_name name
   self.mongo_client['places'].find({"address_components.short_name": name})
  end

  def self.all(offset = 0, limit = 0)
    res = collection.find.skip(offset).limit(limit)
    places = []
    res.each do |r|
      places << Place.new(r)
    end
    return places
  end

  def self.get_address_components(sort = {}, offset = 0, limit = nil)
    query = [ {"$project": {_id: 1, address_components: 1,
                            formatted_address: 1,
                            "geometry.geolocation": 1}},
              {"$unwind": "$address_components"}, {"$skip": offset}]
    query << {"$limit": limit} if !limit.nil?
    query.insert(2, {:$sort => sort}) if sort != {}
    collection.find.aggregate(query)
  end

  def self.get_country_names
    collection.find.aggregate([{"$unwind": "$address_components"},
                               {"$match": {'address_components.types': "country"}},
                               {"$group": {_id: "$address_components.long_name"}},
                               {"$project": {_id: 1}}]).to_a.map {|h| h[:_id]}
  end

  def self.find_ids_by_country_code country_code
    collection.find.aggregate([{"$unwind":  "$address_components"},
                               {"$match": { "address_components.short_name": country_code}},
                               {"$project": {_id: 1}}]).to_a.map {|h| h[:_id].to_s}
  end

  def self.create_indexes
    collection.indexes.create_one({'geometry.geolocation': Mongo::Index::GEO2DSPHERE})
  end

  def self.remove_indexes
    collection.indexes.drop_all
  end

  def self.near(input, max_meters = nil)
    collection.find({'geometry.geolocation': {"$near": {"$geometry": input.to_hash, "$maxDistance": max_meters}}})
  end

  def destroy
    self.class.collection.find({_id: BSON::ObjectId(@id)}).delete_one
  end

  def near(max = nil)
    max = max.nil? ? 1000 : max.to_i
    res = Place.near(@location, max)
    Place.to_places(res)
  end

  def photos(offset = 0, limit = nil)
    res = Photo.find_photos_for_place(@id).skip(offset)
    res = result.limit(limit) if !limit.nil?
    res.map {|r| Photo.new(r)}
  end
end
