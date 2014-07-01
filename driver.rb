require './sprint'

wiki = ""

sprint = Sprint.new

#committed to 
sprint.stories_committed_to
sprint.current_sprint_stories

#backlog
c_totals = sprint.point_totals('committed')
b_totals = sprint.point_totals('backlog')
sprint.apply_end_of_sprint_status
wiki += sprint.to_wiki("Sprint Backlog", c_totals)

#removals
sprint.removals
r_totals = sprint.point_totals('removals')
wiki += sprint.to_wiki("Sprint Removals", r_totals)

#additions
sprint.additions
a_totals = sprint.point_totals('additions')
wiki += sprint.to_wiki("Sprint Additions", a_totals)

#goals and such
wiki += sprint.goals

#summary section
sprint.summary_totals([c_totals, r_totals, a_totals, b_totals])
wiki = "#{sprint.to_wiki_summary}#{wiki}"

#header
wiki = "#{sprint.header}#{wiki}"

puts wiki

