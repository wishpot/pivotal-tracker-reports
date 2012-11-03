class OwnerWork
	attr_reader :name, :story_count, :points_count

	def initialize(name)
		@name = name
		@story_count = 0
		@points_count = 0
	end

	#Add a story (increments count by one) and points (provided)
	def increment(points_count)
		@story_count  += 1
		@points_count += points_count
	end
end