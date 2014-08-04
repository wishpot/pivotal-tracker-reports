
#Given a story type, returns the image name for it
def type_to_img(story_type)
  return "/#{story_type}.png"
end


def status_icon(state)
  "/st-" + state + ".png"
end


def story_to_status_icon(story)
  if story.current_state != "accepted" && !story.labels.nil?
    return status_icon("critical") if story.labels.include? "critical"
    return status_icon("keystone") if story.labels.include? "keystone"
  end
  return status_icon(story.current_state)
end

def http
  return @http if @http
  @http = Net::HTTP.new(@pt_uri.host, 443)
  @http.use_ssl = true
  @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  return @http
end

def friendly_title(story)
  "<a href=\"#{story.url}\" target=\"_blank\" title=\"#{CGI.escapeHTML(story.description[0...80])}\">#{story.title}</a>"
end

#Fetches this week's work - returns the body of the API response
def this_week(project, api_key)
  return _iterations('current', project, api_key)
end

def iterations(project, api_key, limit=1, skip=0)
  return _iterations('current_backlog', project, api_key, limit, skip)
end

#NOTE: in this context, 'skip' means 'how many backwards to skip'
def done(project, api_key, limit=1, skip=0)
  return _iterations('done', project, api_key, limit, (skip*-1)-1)
end

def _iterations(path, project, api_key, limit=nil, skip=nil)
  url = "/services/v3/projects/#{project}/iterations/#{path}?"
  url += "limit=#{limit}&" unless limit.nil?
  url += "offset=#{skip}&" unless skip.nil?

  req = Net::HTTP::Get.new( url, {'X-TrackerToken'=>api_key} )
  res = http.request(req)
  return res.body
end

def icebox(project, api_key, filter='')
  return stories(project, api_key, "state:unscheduled#{filter}")
end

def created_since(date, project, api_key, filter='')
  return stories(project, api_key, "created_since:#{date.strftime("%m/%d/%Y")}%20#{filter}")
end

def modified_since(date, project, api_key, filter='')
  return stories(project, api_key, "modified_since:#{date.strftime("%m/%d/%Y")}%20#{filter}")
end

def parse_stories_from_iterations(html)
  stories = Array.new
  story_iteration_iterator(Nokogiri::HTML(html)) { |story| stories << story }
  return stories
end

#Given an HTML doc, builds a story for each and yields each one
def story_iteration_iterator(doc)
  doc.xpath('//iteration').each do |i|
    due = Date.parse(i.xpath('finish')[0].content)
    i.xpath('//stories//story').each do |s|
      story = Story.new.from_xml(s)
      story.estimated_date = due
      yield story
    end
  end
end

#This wraps the story search
def stories(project, api_key, filter='')
  req = Net::HTTP::Get.new(
    "/services/v5/projects/#{project}/stories?filter=#{filter}",
    {'X-TrackerToken'=>api_key}
  )
  res = http.request(req)
  return JSON.parse(res.body)
end

def memberships(project, api_key, filter='')
  req = Net::HTTP::Get.new(
    "/services/v5/projects/#{project}/memberships",
    {'X-TrackerToken'=>api_key}
  )
  res = http.request(req)
  return JSON.parse(res.body)
end


#Wraps any XML search
def pt_get_body(url, api_key)
  req = Net::HTTP::Get.new(url, {'X-TrackerToken'=>api_key} )
  res = res = http.request(req)
  return Nokogiri::HTML(res.body)
end

def pt_get_body_json(url, api_key)
  req = Net::HTTP::Get.new(url, {'X-TrackerToken'=>api_key} )
  res = res = http.request(req)
  return JSON.parse(res.body)
end