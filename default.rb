require 'sinatra'
require 'sinatra/reloader' if development?
require 'haml'
require 'nokogiri'
require 'net/http'
require 'net/https'
require 'uri'
require 'cgi'
require 'require_relative'
require 'json'
require_relative 'models/story.rb'
require_relative 'models/owner_work.rb'
require_relative 'models/member.rb'
require_relative 'lib/helper.rb'
require 'date' #this is mac-specific, which doesn't require the standard libs.


before do
  @days_ago = params[:days_ago].to_i
  if params[:week] == "current"
    @days_ago = 7 if @days_ago < 1
    @start_date = Date.today-@days_ago
  else
    @days_ago = 7 if @days_ago < 1
    @start_date = Date.today-@days_ago
  end
  @pt_uri = URI.parse('https://www.pivotaltracker.com/')
  $testmode = 1
end

post '/api/:project/:api_key/move/:story_id/:direction/:other_id' do
  req = Net::HTTP::Post.new(
    "/services/v3/projects/#{params[:project]}/stories/#{params[:story_id]}/moves?move\[move\]=#{params[:direction]}&move\[target\]=#{params[:other_id]}",
    {'X-TrackerToken'=>params[:api_key]}
  )
  res = http.request(req)
  return res.body
end

post '/api/:project/:api_key/assign/:story_id/:user_id' do
  req = Net::HTTP::Put.new(
    "/services/v5/projects/#{params[:project]}/stories/#{params[:story_id]}?owned_by_id=#{params[:user_id]}",
    { 'X-TrackerToken'=>params[:api_key],'Content-Length'=>'0' }
  )
  res = http.request(req)
  return http.request(req).body
end

get '/' do
  haml :lol
end

get '/:projects/:api_key' do
    @title = 'Accepted Stories Report'
    @stories = Hash.new
    @labels = Hash.new
    @story_points = 0
    @owner_work = Hash.new

    #this simply assumes all stories are weighted the same, but if a story has multiple labels, it
    #splits it's weight across them.
    @label_weights = Hash.new(0)
    @created_stories = 0

    #which stories are still to come
    @upcoming_stories = Array.new
    @upcoming_story_counts = Hash.new(0)

    params[:projects].split(',').uniq.each do |project|

      doc = Nokogiri::HTML(stories(project, params[:api_key], "state:accepted%20includedone:true%20modified_since:#{@start_date.strftime("%m/%d/%Y")}"))

      doc.xpath('//story').each do |s|
        sid = s.xpath('id')[0].content
        @stories[sid] = Story.new.from_xml(s)
        @story_points += @stories[sid].estimate
        @owner_work[@stories[sid].owned_by] ||= OwnerWork.new(@stories[sid].owned_by) and @owner_work[@stories[sid].owned_by].increment(@stories[sid].estimate)
      end


      begin
        @created_stories += Story.count_stories_from_xml(Nokogiri::HTML(created_since(@start_date, project, params[:api_key])))
        @improved = (@created_stories < @stories.count)
      rescue
      end

      #figure out which stories we expect to come this week
      begin
        doc = Nokogiri::HTML(this_week(project, params[:api_key]))
        doc.xpath('//stories//story').each do |s|
          story = Story.new.from_xml(s)
          if story.accepted_at.nil?
            @upcoming_stories << story
            @upcoming_story_counts[story.current_state] += 1
          end
        end
      end
    end

    @top_labels = Story.top_labels(@stories.values)
    @top_owners = @owner_work.values.sort{|a,b|
      comp = (b.points_count <=> a.points_count )
      comp.zero? ? (b.story_count <=> a.story_count ) : comp
    }

    haml :index
end

get '/status/:projects/:api_key' do

  include_icebox = (params[:icebox] != 'false')
  include_done = (params[:done] != 'false')
  include_backlog = (params[:backlog] != 'false')

  @done_stories = Array.new
  @done_points = 0

  @current_stories = Array.new
  @current_points = 0
  @next_up_stories = Array.new
  @next_points = 0
  @recently_delivered_by_owner = Hash.new

  @recently_logged_stories = Array.new
  @backlog_stories = Array.new
  @icebox = Array.new

  # Used to weed stories out of the list to-be prioritized because
  # we know they're already on the schedule.
  @scheduled_story_ids = Set.new

  params[:projects].split(',').uniq.each do |project|

    #Work done in last iteration
    if(include_done)
       doc = Nokogiri::HTML(done(project, params[:api_key]))
       story_iteration_iterator(doc) do |story|
        if story.accepted_at.nil?
          @recently_delivered_by_owner[story.owned_by] ||= Array.new and @recently_delivered_by_owner[story.owned_by] << story
        else
          @done_stories << story
          @done_points += story.estimate
        end
        @scheduled_story_ids.add(story.story_id)
      end
    end

    #Get the upcoming work
    begin
      doc = Nokogiri::HTML(this_week(project, params[:api_key]))
      story_iteration_iterator(doc) do |story|
        if story.current_state == 'unstarted'
          @next_up_stories << story
          @next_points += story.estimate
        else
          @current_stories << story
          @current_points += story.estimate
        end
        @scheduled_story_ids.add(story.story_id)
      end
    end

    #Grab the rest of the backlog
    if include_backlog
      @backlog_stories = parse_stories_from_iterations(iterations(project, params[:api_key], 3, 1))
      @backlog_stories.each { |story| @scheduled_story_ids.add(story.story_id) }
    end

    #Grab the recently logged stories
    begin
      doc = Nokogiri::HTML(created_since(@start_date, project, params[:api_key], 'state:unscheduled'))
      doc.xpath('//stories//story').each do |s|
        story = Story.new.from_xml(s)
        @recently_logged_stories << story unless @scheduled_story_ids.include?(story.story_id)
      end
    end

    #Grab the icebox
    if(include_icebox)
      doc = Nokogiri::HTML(icebox(project, params[:api_key]))
      doc.xpath('//stories//story').take(20).each do |s|
        @icebox << Story.new.from_xml(s)
      end
    end
  end

  haml :status
end

# Epics
get '/epics/:projects/:api_key' do

  @days_ago = 28
  @start_date = Date.today - @days_ago
  @epics_bugs = Hash.new();
  @epics_features = Hash.new();
  @epics = Array.new()

  params[:projects].split(',').uniq.each { |project| # website=744405, apps=827127
    burl = "/services/v5/projects/#{project}"
    url = burl + "/labels"
    epics = pt_get_body_json(url, params[:api_key])
    epics.each do | epic |
      @epics << epic['name'] if Date.parse(epic['updated_at']) >= @start_date
    end

    @epics.each { |epicname|
      @epics_bugs[epicname] = Array.new()
      @epics_features[epicname] = Array.new()
      @filter="label:\"#{epicname}\"%20modified_since:#{@start_date.strftime("%m/%d/%Y")}"
      @filter.gsub!(/ /, "%20")
      doc = Nokogiri::HTML(stories(project, params[:api_key], @filter))
      doc.xpath('//stories//story').each { |s|
        story = Story.new.from_xml(s)
        if story.story_type.eql? "bug"
           @epics_bugs[epicname] << story
        else
           @epics_features[epicname] << story
        end
      }
    }
  }

  haml :epics
end

# Team
get '/team/:group/:projects/:api_key' do

  @days_ago = 40
  @members = Hash.new(0)
  params[:projects].split(',').uniq.each { |project|

    burl = "/services/v3/projects/#{project}"
    url = burl + "/memberships"
    doc = pt_get_body(url, params[:api_key])
    doc.xpath('//memberships//membership').each { |member_xml|
      m = Member.new()
      m.from_xml(member_xml)
      if !@members.key?(m.name)
        @members[m.name] = m
      end
    }
    if ! @members.has_key?("no one")
      @nobody = Member.new('no one', 'NO')
      @members[@nobody.name] = @nobody
    end

    @start_date = Date.today - @days_ago
    url = burl + "/stories?filter=modified_since:#{@start_date}.strftime('%m/%d/%Y')"
    doc = pt_get_body(url, params[:api_key])
    doc.xpath('//stories//story').each { |xml_story|
      story = Story.new.from_xml(xml_story)
      if @members[story.owned_by].nil?
        next
      end
      @members[story.owned_by].add(story)
    }

  } # :projects

  @members.values.each { |m| m.sort_stories() }
  @current_group = params[:group] || "all"
  haml :team
end
