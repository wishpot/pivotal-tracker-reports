
class Story
attr_reader :id, :title, :description, :url, :accepted_at, :requested_by, :owned_by, :created_at, :story_type
  
# Builds a story given an XML node from pivotal tracker
def from_xml(node)
  @id = node.xpath('id')[0].content
  @title = node.xpath('name')[0].content
  @description = node.xpath('description')[0].content
  @url = node.xpath('url')[0].content
  accepted_at_node = node.xpath('accepted_at')[0]
  @accepted_at = accepted_at_node.nil? ? nil : DateTime.parse(accepted_at_node.content)
  @created_at = DateTime.parse(node.xpath('created_at')[0].content)
  @requested_by = node.xpath('requested_by')[0].content
  owned_by_node = node.xpath('owned_by')[0]
  @owned_by = owned_by_node.nil? || owned_by_node.content.length == 0 ? 'no one' : owned_by_node.content
  @story_type = node.xpath('story_type')[0].content
  self
end

def self.count_stories_from_xml(xml_doc)
  return xml_doc.xpath('//stories')[0].attribute('count').value.to_i
end

#handy for turning labels into something more human readable
def self.human_format(str)
  str.gsub('z_', '').gsub(/[_-]/, ' ').capitalize
end

end