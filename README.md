This is a simple [Sinatra]("http://www.sinatrarb.com/")-based app to summarize Pivotal Tracker
stories that have been completed in the last week.  The output is grouped by label, and sorted
alphabetically.

Url format is: `http://pt-reports.heroku.com/PROJECT_ID/API_KEY`

You can download this code to your own server, or use the sample app on heroku.

The idea with this report is that it can be sent to an audience who isn't in the project tracker regularly.  It includes
the story descriptions, so readers don't need to go back to the tool to understand what was fixed.  It also shows the number
of stories that were created over the same time period, and puts them in red if you created more than you finished, or green
if you finished more than you created.

![Sample Report](http://content.screencast.com/users/tlianza/folders/Jing/media/4086349d-8765-4093-9cbf-9303f55ae06c/2011-02-19_1355.png)


## Setup
1. git clone git://github.com/wishpot/pivotal-tracker-reports.git
2. cd pivotal-tracker-reports
3. bundle install
4. ruby -rubygems default.rb