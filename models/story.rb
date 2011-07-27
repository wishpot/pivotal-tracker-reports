
class Story
attr_reader :title, :description, :url, :accepted_at, :requested_by, :owned_by, :created_at, :story_type
  
# Builds a story given an XML node from pivotal tracker
def from_xml(node)
  @title = node.xpath('name')[0].content
  @description = node.xpath('description')[0].content
  @url = node.xpath('url')[0].content
  @accepted_at = DateTime.parse(node.xpath('accepted_at')[0].content)
  @created_at = DateTime.parse(node.xpath('created_at')[0].content)
  @requested_by = node.xpath('requested_by')[0].content
  @owned_by = node.xpath('owned_by')[0].content
  @story_type = node.xpath('story_type')[0].content
  self
end

#handy for turning labels into something more human readable
def self.human_format(str)
  str.gsub('z_', '').gsub('_', ' ').capitalize
end

end