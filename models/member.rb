# EXAMPLE of Member xml
#
#	<memberships type="array">
#		<membership>
#			<id>2795451</id>
#			<person>
#				<email>kevin@ador.com</email>
#				<name>Kevin Chen</name>
#				<initials>KC</initials>
#			</person>
#			<role>Owner</role>
#			<project>
#				<id>744405</id>
#				<name>Ador.com</name>
#			</project>
#		</membership>


class Member
	attr_reader :id, :email, :name, :intials, :nickname, :moniker, :group
	attr_reader :features, :bugs, :feature_count, :feature_points, :bug_count, :bug_points

	# don't want class vars & actions in initialize() as only needed once
	@@testmode = 1
	@@monikers = Hash[*File.read('etc/monikers.txt').split(/\s*=>\s*|\n/)]
	@@groups = Hash[*File.read('etc/groups.txt').split(/\s*=>\s*|\n/)]
	if (@@testmode > 3)
		p "MONIKER HASH:"
		@@monikers.each { |k,v| puts "  MONIKER: k=>v: #{k}=>#{v}, CHK:#{@@monikers[k]}" }
		@@groups.each { |k,v| puts "  GROUP: k=>v: #{k}=>#{v}, CHK:#{@@groups[k]}" }
	end

	@@STATUS_RANKS = { 'critical'=>0, 'keystone'=>1, 'accepted'=>2, 'rejected'=>3, 'delivered'=>4, 'finished'=>5, 'started'=>6, 'unstarted' => 7, 'unscheduled' => 8 }


def initialize(name = 'no one', initials = 'NO')
	@name = name
	@initials = initials
	@features = Array.new(0)
	@bugs = Array.new(0)
	@moniker = 'Nobody'
	@feature_count = 0
	@feature_points = 0
	@bug_count = 0
	@bug_points = 0
	@group = "other"
end


# Builds a member given an XML node from pivotal tracker
def from_xml(node)

	@id = node.xpath('id')[0].content
	@email = node.xpath('person/email')[0].content
	@name = node.xpath('person/name')[0].content
	@initials = node.xpath('person/initials')[0].content
	#@moniker = @@monikers[@initials] || "Who is #{@initials}?"
	#@moniker = @name if @moniker.nil?
	@moniker = @@monikers[@initials] || @name
	@group = @@groups[@initials] || "other"
	@role = node.xpath('role')[0].content

	if (@@testmode > 3)
		puts "Id = #{@id}"
		puts "email = #{@email}"
		puts "name = #{@name}"
		puts "initials = #{@initials}"
		puts "moniker = #{@moniker}"
		puts "role = #{@role}"
	end


	self    # needed to invoke method on .new - e.g. .new.from_xml()
end


def add(story)

	@points = story.estimate || 2
	if story.story_type.eql? "bug"
		@bugs << story
		@bug_count += 1
	else
		@features << story
		@feature_count += 1
		@feature_points += @points
	end
end


def get_states()
	return @@STATUS_RANKS.keys
end


def sort_stories()
	@features.sort! { |a,b| @@STATUS_RANKS[a.current_state] <=> @@STATUS_RANKS[b.current_state] }
	@bugs.sort! { |a,b| @@STATUS_RANKS[a.current_state] <=> @@STATUS_RANKS[b.current_state] }
	return true
end


end

