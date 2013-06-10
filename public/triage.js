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

	function apiCall(project, path, params, callback) {
		return $http.jsonp('http://xml2json.heroku.com?url='+encodeURIComponent('https://www.pivotaltracker.com/services/v3/projects/'+project+path+'?token='+qs['api_key']+'&'+params)+'&callback=JSON_CALLBACK').success(callback);
	}

	function sortStory(story) {
		return story.current_state;
	}

	function getOwner(story) { return (story && story.owned_by) ? story.owned_by : 'Nobody'; }
	$scope.getOwner = getOwner;

	$scope.isUnstarted = function(story){ return (story.current_state == 'unstarted' || story.current_state == 'unscheduled'); }

	function addStoriesToObj(obj, iterations) {
		var storiesAdded = new Array();
		 _.each(iterations, function(iteration){
		    _.each(iteration.stories, function(story) {
		    	if(null == obj[getOwner(story)]) {
		    		obj[getOwner(story)] = {};
		    		obj[getOwner(story)].name = getOwner(story);
		    		obj[getOwner(story)].stories = new Array();
		    	}
		    	if(story.current_state != 'accepted') {
		    		storiesAdded.push(story);
		    		obj[getOwner(story)].stories.push(story);
		    	}
		    });
		});
		return storiesAdded;
	}

	$scope.currentByUser = {};
	$scope.recentlyScheduled = new Array();

	//these are hashed by project id
	$scope.firstInBacklog = {};
	$scope.lastInBacklog = {};
	$scope.firstInIcebox = {};

	var scheduledStoryCalls = new Array();

	_.each(projects, function(project) {

		//current work
		scheduledStoryCalls.push(apiCall(project, '/iterations/current', '', function(data) {
			var stories = addStoriesToObj($scope.currentByUser, data.iterations);
			//initialize the 'first' and 'last' in backlog to whatever's last in the current iteration.
			if(null == $scope.firstInBacklog[project]) {
				$scope.firstInBacklog[project] = stories[stories.length-1];
			}
			if(null == $scope.lastInBacklog[project]) {
				$scope.lastInBacklog[project] = stories[stories.length-1];
			}
		}));

		//backlog work
		scheduledStoryCalls.push(apiCall(project, '/iterations/current_backlog', 'limit=3&offset=1', function(data) {
			var stories = addStoriesToObj($scope.currentByUser, data.iterations);
			$scope.firstInBacklog[project] = stories[0];
			$scope.lastInBacklog[project] = stories[stories.length-1];
		}));

		//recently scheduled stories
		apiCall(project, '/stories', 'filter=state:unscheduled%20created_since:'+dateStr, function(data) {
		   $scope.recentlyScheduled = $scope.recentlyScheduled.concat(data.stories);		 
		});

		//get the top of the icebox
		apiCall(project, '/stories', 'limit=1&filter=state:unscheduled', function(data) {
		   $scope.firstInIcebox[project] = data.stories[0];		 
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

	function getUserStories(userName) {
		return _.find($scope.currentByUser, function(c){return c.name==userName;});
	}

	$scope.moveTop = function(story) {
		move(story, 'before', $scope.firstInBacklog[story.project_id])
			.success(function(data){
				deleteFromCollectionById($scope.recentlyScheduled, story.id);
				getUserStories(getOwner(story)).stories.push(story);
			})
			.error(function(data) {
				alert("Fail: "+data);
			})
	}

	$scope.moveBottom= function(story) {
		move(story, 'after', $scope.lastInBacklog[story.project_id])
			.success(function(data){
				deleteFromCollectionById($scope.recentlyScheduled, story.id);
				getUserStories(getOwner(story)).stories.push(story);
			})
			.error(function(data) {
				alert("Fail: "+data);
			})
	}

	$scope.ice = function(story) {
		move(story, 'before', $scope.firstInIcebox[story.project_id])
			.success(function(data){
				$scope.recentlyScheduled.push(story);
				deleteFromCollectionById(getUserStories(getOwner(story)).stories, story.id);
			})
			.error(function(data) {
				alert("Fail: "+data);
			})
	}
}
