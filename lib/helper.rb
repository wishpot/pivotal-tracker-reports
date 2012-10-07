
#Given a story type, returns the image name for it
def type_to_img(story_type)
  return "/#{story_type}.png"
end

def friendly_title(story)
	"<a href=\"#{story.url}\" target=\"_blank\" title=\"#{CGI.escapeHTML(story.description)}\">#{story.title}</a>"
end

#Fetches this week's work - returns the body of the API response
def this_week(project, api_key)
	req = Net::HTTP::Get.new(
	      "/services/v3/projects/#{project}/iterations/current_backlog?limit=1", 
	      {'X-TrackerToken'=>api_key}
	    )
	res = Net::HTTP.start(@pt_uri.host, @pt_uri.port) {|http|
	  http.request(req)
	}
	return res.body
end