var qs = (function(a) {
    if (a == "") return {};
    var b = {};
    for (var i = 0; i < a.length; ++i)
    {
        var p=a[i].split('=');
        if (p.length != 2) continue;
        b[p[0]] = decodeURIComponent(p[1].replace(/\+/g, " "));
    }
    return b;
})(window.location.search.substr(1).split('&'));

function TriageCtl($scope, $http, $location, $q) {

	var projects = qs['projects'].split(',');
	var sinceDate = new Date();
	sinceDate.setDate(sinceDate.getDate() - (qs['days_ago'] || 7));
	var dateStr = (sinceDate.getMonth()+1)+"/"+sinceDate.getDate()+"/"+sinceDate.getFullYear();
	var APIv5PREFIX = "https://www.pivotaltracker.com/services/v5";

	function sortStory(story) {
		return story.current_state;
	}

	$scope.getOwnerName = function(id){ return $scope.membersById[id] ? $scope.membersById[id].name : 'Nobody'; }
	$scope.getOwnerInitials = function(id){ return $scope.membersById[id] ? $scope.membersById[id].initials : '??'; }


	$scope.isUnstarted = function(story){ return (story.current_state == 'unstarted' || story.current_state == 'unscheduled'); }

	function addStoriesToObj(obj, stories) {
		var storiesAdded = new Array();
	    _.each(stories, function(story) {
	    	if(null == obj[story.owned_by_id]) {
	    		obj[story.owned_by_id] = {};
				obj[story.owned_by_id].stories = new Array();
				obj[story.owned_by_id].user_id = story.owned_by_id;
	    	}
	    	if(story.current_state != 'accepted') {
	    		storiesAdded.push(story);
	    		obj[story.owned_by_id].stories.push(story);
	    	}
	    });
		return storiesAdded;
	}

	$scope.currentByUser = {};
	$scope.recentlyScheduled = new Array();
	$scope.members = new Array();
	$scope.membersById = new Array();

	//these are hashed by project id
	$scope.firstInBacklog = {};
	$scope.middleInBacklog = {};
	$scope.lastInBacklog = {};
	$scope.firstInIcebox = {};

	var scheduledStoryCalls = new Array();

	_.each(projects, function(project) {

		//gett all members
		scheduledStoryCalls.push(
			$http.get(APIv5PREFIX+'/projects/'+project+'/memberships?token='+qs['api_key']).success(
				function(data){
					$scope.members[project] = data;
					 _.each(data, function(u) {
					 	$scope.membersById[u.person.id] = u.person;
					});
				}
			)
		);

		//current work
		scheduledStoryCalls.push(
			$http.get(APIv5PREFIX+'/projects/'+project+'/iterations?scope=current&token='+qs['api_key']).success(function(data){
				var stories = addStoriesToObj($scope.currentByUser, data[0].stories);

				//initialize the 'first' and 'last' in backlog to whatever's last in the current iteration.
				if(null == $scope.firstInBacklog[project]) {
					$scope.firstInBacklog[project] = stories[0];
				}
				if(null == $scope.lastInBacklog[project]) {
					$scope.lastInBacklog[project] = stories[stories.length-1];
				}
				if(null == $scope.middleInBacklog[project]) {
					$scope.middleInBacklog[project] = $scope.lastInBacklog[project];
				}
			})
		);

		//backlog work
		scheduledStoryCalls.push(
				$http.get(APIv5PREFIX+'/projects/'+project+'/iterations?scope=current_backlog&limit=3&offset=1&token='+qs['api_key']).success(function(data){
				var stories = addStoriesToObj($scope.currentByUser, data[0].stories);
				$scope.firstInBacklog[project] = stories[0];
				$scope.lastInBacklog[project] = stories[stories.length-1];
				$scope.middleInBacklog[project] = stories[Math.round(stories.length/2)];
				console.log("["+project+"] First: "+$scope.firstInBacklog[project].name+" Mid: "+$scope.middleInBacklog[project].name+" Last: "+$scope.lastInBacklog[project].name);
			})
		);

		//recently scheduled stories
		$http.get(APIv5PREFIX+'/projects/'+project+'/stories?filter=state:unscheduled%20created_since:'+dateStr+'&token='+qs['api_key']).success(function(data){
		   $scope.recentlyScheduled = $scope.recentlyScheduled.concat(data);
		});

		//get the top of the icebox
		$http.get(APIv5PREFIX+'/projects/'+project+'/stories?limit=1&filter=state:unscheduled&token='+qs['api_key']).success(function(data){
			$scope.firstInIcebox[project] = data[0];
		});
		
	});

	$q.all(scheduledStoryCalls).then(function(data){
		_.each($scope.currentByUser, function(u){
	    	u.stories = _.sortBy(u.stories, sortStory);
	    	u.points  = _.reduce(u.stories, function(sum, story){ return sum + (story.estimate||0); }, 0);
	    });
	    $scope.currentByUser = _.sortBy( $scope.currentByUser, function(u) {return -1 * u.stories.length});
	})

	function move(story, direction, otherStory) {
		return $http.post('/api/'+story.project_id+'/'+qs['api_key']+'/move/'+story.id+'/before/'+otherStory.id, {})
	}

	function deleteFromCollectionById(collection, id) {
		for(var i=0; i<collection.length; i++) {
			if(collection[i].id == id) { collection.splice(i,1); return;}
		}
	}

	function getUserStories(userId) {
		return _.find($scope.currentByUser, function(c){return c.user_id==userId;});
	}

	function promoteRecent(story, direction, target) {
		return move(story, direction, target)
			.success(function(data){
				deleteFromCollectionById($scope.recentlyScheduled, story.id);
				getUserStories(story.owned_by_id).stories.push(story);
			})
			.error(function(data) {
				alert("Fail: "+data);
			});
	}

	$scope.moveTop = function(story) {
		return promoteRecent(story, 'before', $scope.firstInBacklog[story.project_id]);
	}

	$scope.moveBottom= function(story) {
		return promoteRecent(story, 'after', $scope.lastInBacklog[story.project_id]);
	}

	$scope.moveMiddle= function(story) {
		return promoteRecent(story, 'after', $scope.middleInBacklog[story.project_id]);
	}

	$scope.ice = function(story) {
		move(story, 'before', $scope.firstInIcebox[story.project_id])
			.success(function(data){
				$scope.recentlyScheduled.push(story);
				deleteFromCollectionById(getUserStories(story.owned_by_id).stories, story.id);
			})
			.error(function(data) {
				alert("Fail: "+data);
			})
	}

}
