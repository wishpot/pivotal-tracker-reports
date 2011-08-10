
class Story
attr_reader :id, :title, :description, :url, :accepted_at, :requested_by, :owned_by, :created_at, :story_type, :current_state
  
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
  @current_state = node.xpath('current_state')[0].content
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

#This is the label for status that we show in the report
def friendly_state
  return '' if current_state == 'unstarted'
  return 'in progress' if current_state == 'started'
  current_state
end

#Simplified version from the rails source
#http://api.rubyonrails.org/classes/ActionView/Helpers/TextHelper.html

AUTO_LINK_RE	=	%r{ (?: ([\w+.:-]+:)// | www\. ) [^\s<]+ }x
AUTO_LINK_CRE	=	[/<[^>]+$/, /^[^>]*>/, /<a\b.*?>/i, /<\/a>/i]
BRACKETS		=	{ ']' => '[', ')' => '(', '}' => '{' }

def self.auto_link_urls(text)
          text.gsub(AUTO_LINK_RE) do
            scheme, href = $1, $&
            punctuation = []

            if auto_linked?($`, $')
              # do not change string; URL is already linked
              href
            else
              # don't include trailing punctuation character as part of the URL
              while href.sub!(/[^\w\/-]$/, '')
                punctuation.push $&
                if opening = BRACKETS[punctuation.last] and href.scan(opening).size > href.scan(punctuation.last).size
                  href << punctuation.pop
                  break
                end
              end

              link_text = href
              href = 'http://' + href unless scheme
			
			  
              #content_tag(:a, link_text, {'href' => href, 'target'=>'_blank'}, !!options[:sanitize]) + punctuation.reverse.join('')
              "<a href=\"#{href}\" target=\"_blank\">#{link_text}</a>" + punctuation.reverse.join('')
            end
          end
        end


private 

def self.auto_linked?(left, right)
  (left =~ AUTO_LINK_CRE[0] and right =~ AUTO_LINK_CRE[1]) or
    (left.rindex(AUTO_LINK_CRE[2]) and $' !~ AUTO_LINK_CRE[3])
end

end