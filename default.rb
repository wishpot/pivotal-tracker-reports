require 'sinatra'
require 'sinatra/reloader' if development?
require 'haml'
require 'nokogiri'
require 'net/http'
require 'uri'
require 'models/story.rb'

get '/:project/:api_key' do
  
    days_ago = params[:days_ago].to_i 
    days_ago = 7 if days_ago < 1
    @start_date = Date.today-days_ago
  
    url = URI.parse('http://www.pivotaltracker.com/')
    req = Net::HTTP::Get.new(
      "/services/v3/projects/#{params[:project]}/stories?filter=state:accepted%20modified_since:#{@start_date.strftime("%m/%d/%Y")}", 
      {'X-TrackerToken'=>params[:api_key]}
    )
    res = Net::HTTP.start(url.host, url.port) {|http|
      http.request(req)
    }
    
    @stories = Hash.new
    @labels = Hash.new
    doc = Nokogiri::HTML(res.body)
    doc.xpath('//story').each do |s| 
      sid = s.xpath('id')[0].content
      @stories[sid] = Story.new.from_xml(s)
      labelnode = s.xpath('labels')[0]
      if labelnode.nil?
        @labels['z_uncategorized'] = Array.new unless @labels.has_key?('z_uncategorized')
        @labels['z_uncategorized'] << sid
      else
        labelnode.content.split(',').each do |l| 
          @labels[l] = Array.new unless @labels.has_key?(l)
          @labels[l] << sid 
        end
      end
    end
    haml :index
end