
class Story
  attr_reader :story_id, :title, :description, :url, :accepted_at, :requested_by, :owned_by, :created_at, :story_type, :current_state, :estimate, :updated_at, :labels
  attr_accessor :estimated_date

  # Builds a story given an XML node from pivotal tracker
  def from_xml(node)
    @story_id = node['id']
    @title = node['name']
    @description = node['description'] || ""
    @url = node['url']
    accepted_at_node = node['accepted_at']
    @accepted_at = accepted_at_node.nil? ? nil : DateTime.parse(accepted_at_node)
    @created_at = DateTime.parse(node['created_at'])
    @updated_at = DateTime.parse(node['updated_at'])
    @requested_by_id = node['requested_by_id']
    @current_state = node['current_state']
    owned_by_node = node['owned_by']
    @owned_by_id = node['owned_by_id'] # owned_by_node.nil? || owned_by_node.length == 0 ? 'no one' : owned_by_node
    @story_type = node['story_type']
    estimate_node = node['estimate']
    @estimate = estimate_node.nil? ? 0 : estimate_node.to_i
    @estimate = 0 if @estimate < 0
    labelnode = node['labels']
    @labels = labelnode

    self
  end

  def owned_by(owners)
    if owners[@owned_by_id]
      return owners[@owned_by_id]['name']
    else
      "no one"
    end
  end

  def requested_by(owners)
    if owners[@requested_by_id]
      return owners[@requested_by_id]['name']
    else
      "no one"
    end
  end

  def self.count_stories_from_xml(xml_doc)
    return xml_doc.xpath('//stories')[0].attribute('count').value.to_i
  end

  #handy for turning labels into something more human readable
  def self.human_format(str)
    return str if str.nil?
    str['name'].gsub('z_', '').gsub(/[_-]/, ' ').capitalize
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
