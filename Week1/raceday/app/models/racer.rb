class Racer
  include Mongoid::Document
  include ActiveModel::Model

  attr_accessor :id, :number, :first_name, :last_name, :gender, :group, :secs

  def initialize(params={})
    @id=params[:_id].nil? ? params[:id] : params[:_id].to_s
    @number=params[:number].to_i
    @first_name=params[:first_name]
    @last_name=params[:last_name]
    @gender=params[:gender]
    @group=params[:group]
    @secs=params[:secs].to_i
  end

  def self.mongo_client
    return Mongoid::Clients.default
  end

  def self.all(prototype={}, sort={ number: 1 }, skip=0, limit=nil)
    res = self.mongo_client['racers'].find(prototype).sort(sort).skip(skip)
    res = res.limit(limit) if !limit.nil?
    return res
  end

  def self.find id
    id = BSON::ObjectId(id) if id.is_a?(String)
    result = self.mongo_client['racers'].find(_id: id).first
    return result.nil? ? nil : Racer.new(result)
  end

  def save
    res=self.class.collection.insert_one(_id: @id,
                                            number: @number,
                                            first_name: @first_name,
                                            last_name: @last_name,
                                            gender: @gender,
                                            group: @group,
                                            secs: @secs);
    @id=res.inserted_id.to_s
  end

  def update(params)
    @number=params[:number].to_i
    @first_name=params[:first_name]
    @last_name=params[:last_name]
    @secs=params[:secs].to_i
    @gender=params[:gender]
    @group=params[:group]

    params.slice!(:number, :first_name, :last_name, :gender, :group, :secs)
    self.class.collection.find(_id: BSON::ObjectId(@id)).update_one(:$set => {number: @number,
                                                                              first_name: @first_name,
                                                                              last_name: @last_name,
                                                                              gender: @gender,
                                                                              group: @group,
                                                                              secs: @secs})
  end

  def destroy
    self.class.collection.find(_id: BSON::ObjectId(@id)).delete_one
  end

  def persisted?
    !@id.nil?
  end

  def created_at
    nil
  end

  def updated_at
    nil
  end

  def self.paginate(params)
    page=(params[:page] || 1).to_i
    limit=(params[:per_page] || 30).to_i
    skip=(page-1)*limit
    racers=[]


    set = self.all({}, { number: 1 }, skip, limit).find.map{|x| Racer.new(x)}
    set.each do |x|
      racers << x
    end
    
    total = self.all({}, { number: 1 }, skip, limit).count

    WillPaginate::Collection.create(page, limit, total) do |pager|
      pager.replace(racers)
    end
  end
end
