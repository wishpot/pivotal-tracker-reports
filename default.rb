require 'sinatra'
require 'sinatra/reloader' if development?
require 'haml'
require 'nokogiri'
require 'net/http'
require 'uri'
require 'models/story.rb'
require 'lib/helper.rb'
require 'date' #this is mac-specific, which doesn't require the standard libs.

before do
   days_ago = params[:days_ago].to_i 
   days_ago = 7 if days_ago < 1
   @start_date = Date.today-days_ago
   @pt_uri = URI.parse('http://www.pivotaltracker.com/')
end

get '/:projects/:api_key' do

    @stories = Hash.new
    @labels = Hash.new
    
    #this simply assumes all stories are weighted the same, but if a story has multiple labels, it
    #splits it's weight across them.
    @label_weights = Hash.new(0)
    @created_stories = 0

    #which stories are still to come
    @upcoming_stories = Array.new

    params[:projects].split(',').each do |project|

      req = Net::HTTP::Get.new(
        "/services/v3/projects/#{project}/stories?filter=state:accepted%20includedone:true%20modified_since:#{@start_date.strftime("%m/%d/%Y")}", 
        {'X-TrackerToken'=>params[:api_key]}
      )
      res = Net::HTTP.start(@pt_uri.host, @pt_uri.port) {|http|
        http.request(req)
      }
       
      
      doc = Nokogiri::HTML(res.body)
      doc.xpath('//story').each do |s| 
        sid = s.xpath('id')[0].content
        @stories[sid] = Story.new.from_xml(s)
        labelnode = s.xpath('labels')[0]
        if labelnode.nil?
          @labels['z_uncategorized'] = Array.new unless @labels.has_key?('z_uncategorized')
          @labels['z_uncategorized'] << sid
          @label_weights['z_uncategorized'] +=1
        else
          labels = labelnode.content.split(',')
          labels.each do |l| 
            @labels[l] = Array.new unless @labels.has_key?(l)
            @labels[l] << sid 
            @label_weights[l] += 1.to_f/labels.count
          end
        end
      end
      
      
      begin
        req = Net::HTTP::Get.new(
          "/services/v3/projects/#{project}/stories?filter=created_since:#{@start_date.strftime("%m/%d/%Y")}", 
          {'X-TrackerToken'=>params[:api_key]}
        )
        res = Net::HTTP.start(@pt_uri.host, @pt_uri.port) {|http|
          http.request(req)
        }
        @created_stories = Story.count_stories_from_xml(Nokogiri::HTML(res.body))
        @improved = (@created_stories < @stories.count)
      rescue
      end
      
      #figure out which stories we expect to come this week
      begin
        req = Net::HTTP::Get.new(
          "/services/v3/projects/#{project}/iterations/current_backlog?limit=1", 
          {'X-TrackerToken'=>params[:api_key]}
        )
        res = Net::HTTP.start(@pt_uri.host, @pt_uri.port) {|http|
          http.request(req)
        }
        doc = Nokogiri::HTML(res.body)
        doc.xpath('//stories//story').each do |s|
          story = Story.new.from_xml(s)
          @upcoming_stories << story if story.accepted_at.nil?
        end
      end
    end

    #summarize the most-worked labels into an array of percentages
    @top_labels = @label_weights.sort{|a,b| b[1]<=>a[1]}[0..2].each{|n| n[1] = ((n[1].to_f/@stories.count)*100).to_i }
    
    haml :index
end
