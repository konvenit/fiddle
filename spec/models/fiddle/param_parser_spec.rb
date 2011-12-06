require 'spec_helper'

describe Fiddle::ParamParser do
  fixtures :fiddle_cubes, :fiddle_projections, :fiddle_relations, :fiddle_constraints

  def build(*a)
    described_class.new fiddle_cubes(:stats), *a
  end

  def where(hash)
    build(:where => hash).operations.map do |o|
      [o.constraint.param_key, o.class.code, *o.sql_args]
    end
  end

  subject do
    build
  end

  it "should have a parent" do
    subject.parent.should == fiddle_cubes(:stats)
  end

  it "should should parse measures" do
    subject.measures.should =~ fiddle_projections(:page_views, :visits, :ppv)
    build(:select => ["page_views", "ppv", "invalid"]).measures.should =~ fiddle_projections(:page_views, :ppv)
    build(:select => "page_views|ppv|invalid").measures.should =~ fiddle_projections(:page_views, :ppv)
    build(:select => ["page_views|ppv|invalid"]).measures.should =~ fiddle_projections(:page_views, :ppv)
    build(:select => ["page_views|invalid", "ppv"]).measures.should =~ fiddle_projections(:page_views, :ppv)
    build(:select => "page_views|page_views").measures.should =~ [fiddle_projections(:page_views)]
    build(:select => "invalid_a|invalid_b").measures.should =~ subject.measures
  end

  it "should should parse dimensions" do
    subject.dimensions.should =~ fiddle_projections(:website_id, :website_name, :date)
    build(:by => "website_id").dimensions.should =~ [fiddle_projections(:website_id)]
  end

  it "should should parse sort orders" do
    subject.orders.should == []
    build(:order => "website_id.desc|page_views").orders.should have(2).items
    build(:order => "website_id.desc|page_views").orders.first.should be_a(Fiddle::SortOrder)
    build(:order => "website_id.desc|page_views").orders.should == ["website_id DESC", "page_views ASC"]
    build(:order => ["website_id.0", "page_views.1"]).orders.should == ["website_id ASC", "page_views DESC"]
    build(:order => ["website_id.d"]).orders.should == ["website_id DESC"]
    build(:order => ["website_id.x"]).orders.should == ["website_id ASC"]
    build(:order => ["invalid.d"]).orders.should == []
  end

  it "should parse limits" do
    subject.limit.should == 100
    build(:limit => "30").limit.should == 30
    build(:per_page => "30").limit.should == 30
    build(:limit => 20, :per_page => "30").limit.should == 20
  end

  it "should parse offsets" do
    subject.offset.should == 0
    build(:offset => "200").offset.should == 200
    build(:page => "2", :per_page => 30).offset.should == 30
    build(:offset => "200", :page => 3, :per_page => "30").offset.should == 200
  end

  it 'should parse operations' do
    subject.operations.should == []
    where("WRONG").should == []
    where("page_views.in" => "1|2").should == []
    where("page_views.gt" => "1").should == [['page_views.gt', 'gt', 1]]
    where("page_views__gt" => "1").should == [['page_views.gt', 'gt', 1]]
    where("page_views.gt" => "A").should == []
    where("page_views.gt" => "1", "website.eq" => "my", "date__between" => "-30..-1").should =~ [
      ['page_views.gt', 'gt', 1],
      ['website.eq', 'eq', "my"],
      ['date.between', 'between', 30.days.ago.to_date, 1.day.ago.to_date]
    ]
  end

  it 'should convert to options hash' do
    subject.to_hash.keys.should =~ [:operations, :dimensions, :limit, :measures, :offset, :orders]
    subject.to_hash.values_at(:dimensions, :measures, :operations, :orders).map(&:size).should == [3, 3, 0, 0]
  end

end
