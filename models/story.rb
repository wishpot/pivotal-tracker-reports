
class Story
attr_reader :story_id, :title, :description, :url, :accepted_at, :requested_by, :owned_by, :created_at, :story_type, :current_state, :estimate, :updated_at, :labels
attr_accessor :estimated_date

# Builds a story given an XML node from pivotal tracker
def from_xml(node)
  @story_id = node.xpath('id')[0].content
  @title = node.xpath('name')[0].content
  @description = node.xpath('description')[0].content unless node.xpath('description')[0].nil?
  @url = node.xpath('url')[0].content
  accepted_at_node = node.xpath('accepted_at')[0]
  @accepted_at = accepted_at_node.nil? ? nil : DateTime.parse(accepted_at_node.content)
  @created_at = DateTime.parse(node.xpath('created_at')[0].content)
  @updated_at = DateTime.parse(node.xpath('updated_at')[0].content)
  @requested_by = node.xpath('requested_by')[0].content
  @current_state = node.xpath('current_state')[0].content
  owned_by_node = node.xpath('owned_by')[0]
  @owned_by = owned_by_node.nil? || owned_by_node.content.length == 0 ? 'no one' : owned_by_node.content
  @story_type = node.xpath('story_type')[0].content
  estimate_node = node.xpath('estimate')[0]
  @estimate = estimate_node.nil? ? 0 : estimate_node.content.to_i
  @estimate = 0 if @estimate < 0
  labelnode = node.xpath('labels')[0]
  @labels = labelnode.content.split(',') unless labelnode.nil?

  self
end

def self.count_stories_from_xml(xml_doc)
  return xml_doc.xpath('//stories')[0].attribute('count').value.to_i
end

#handy for turning labels into something more human readable
def self.human_format(str)
  return str if str.nil?
  str.gsub('z_', '').gsub(/[_-]/, ' ').capitalize
end

#This is the label for status that we show in the report
def friendly_state
  return '' if current_state == 'unstarted'
  return 'in progress' if current_state == 'started'
  current_state
end

# Given two stories (a and b) this is how you'd sort them
# if you wanted to sort by status
def self.status_sort(a,b)
  STATUS_PRIORITY[a.current_state] <=> STATUS_PRIORITY[b.current_state]
end

STATUS_PRIORITY = { 'accepted'=>0, 'rejected'=>1, 'delivered'=>2, 'finished'=>3, 'started'=>4 }

def self.top_labels(story_array, limit=3)
  #this simply assumes all stories are weighted the same, but if a story has multiple labels, it
  #splits it's weight across them.
  @label_weights = Hash.new(0)
  @labels = Hash.new

  story_array.each { |story|
    if story.labels.nil?
      @labels['z_uncategorized'] = Array.new unless @labels.has_key?('z_uncategorized')
      @labels['z_uncategorized'] << story.story_id 
      @label_weights['z_uncategorized'] +=1
    else
      story.labels.each do |l| 
        @labels[l] = Array.new unless @labels.has_key?(l)
        @labels[l] << story.story_id 
        @label_weights[l] += 1.to_f/story.labels.count
      end
    end
  }
  #summarize the most-worked labels into an array of percentages
  @label_weights.sort{|a,b| b[1]<=>a[1]}[0..limit].each{|n| n[1] = ((n[1].to_f/story_array.count)*100).to_i }
end

#Simplified version from the rails source
#http://api.rubyonrails.org/classes/ActionView/Helpers/TextHelper.html

AUTO_LINK_RE	=	%r{ (?: ([\w+.:-]+:)// | www\. ) [^\s<]+ }x
AUTO_LINK_CRE	=	[/<[^>]+$/, /^[^>]*>/, /<a\b.*?>/i, /<\/a>/i]
BRACKETS		=	{ ']' => '[', ')' => '(', '}' => '{' }

def self.auto_link_urls(text)
          return text if text.nil?
          
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
