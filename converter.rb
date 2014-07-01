module StoryConverter
  STATE_MAP = { 'accepted' => "'''completed'''" }
  TITLE_MAP = { 
    'Sprint Overview' => '',
    'Sprint Backlog' => "These are the actionable stories that were committed to during Sprint Planning\
    according to priority as directed by the Product Owner.",
    'Sprint Removals' => "These are stories that were removed from the sprint after Sprint Planning.",
    'Sprint Additions' => "These are stories that were added to the sprint after Sprint Planning. Stories\
    should not be added to a Sprint unless all the committed stories have been completed.",
    'Sprint Improvement Goals' => "At the end of each Sprint, the team identifies areas to incrementally\
    improve. Below are the things identified in the previous Sprint:",
    'Sprint Retrospective Notes' => "Each Sprint ends with a Sprint Retrospective, where the team inspects\
    how the Sprint went, and identifies areas to adapt in order to improve the process on the next pass.\
    These are summary notes from that meeting.",
    'What\'s Working' => '',
    'Not Working or Need to Tweak' => '',
    'Things to Try Next Sprint' => '',
    'Estimations of Story Point' => ''}

  def wiki_header(title)
    section_title(title) +
    <<-EOF
{| border="1"
|+ #{title}
! User Story
! Product
! Story Type
! Pivotal #
! End of Sprint Status
! Story Points
    EOF
  end

  def wiki_footer(section, *args)
    <<-EOF 
|-
| colspan=\"5\" align=\"right\" | '''Feature Story Points'''
| align=\"right\" | '''#{args[0]}'''
|-
| colspan=\"5\" align=\"right\" | '''Bug Story Points'''
| align=\"right\" | '''#{args[1]}'''
|-
| colspan=\"5\" align=\"right\" | '''Chore Story Points'''
| align=\"right\" | '''#{args[2]}'''
|-
| colspan=\"5\" align=\"right\" | '''Total Story Points'''
| align=\"right\" | '''#{args[3]}'''
|}
    EOF
  end

  def wiki_body(section, stories, remove_state=false)
    ret_wiki=""
    stories.each do |story|
      ret_wiki += "|-\n"
      ret_wiki+="| #{story.name}\n"
      ret_wiki+="| #{story.labels}\n"
      ret_wiki+="| #{story.story_type}\n"
      ret_wiki+="| {{Pivotal|#{story.id}}}\n"
      ret_wiki+="| align=\"right\" | #{remove_state ? "" : map_state(story.current_state)}\n"
      ret_wiki+="| align=\"right\" | '''#{story.estimate}'''\n"
    end
    ret_wiki
  end

  def to_wiki(section, *args)
    remove_state = args[0].member?('remove_state')
    "#{wiki_header(section)}#{wiki_body(section, args[0][0], remove_state)}#{wiki_footer(section, args[0][1], args[0][2], args[0][3], args[0][4])}"
  end

  def map_state(state)
    STATE_MAP[state] or state
  end

  def to_pivotal_stories(wiki)
    log = open(wiki).read
    out = log.split("|-").reject {|line| line if line[0..1] != "\n|" or line[0..13] == "\n| colspan=\"5\"" }
    stories = out.map { |line| WikiStory.new(line) }
  end

  class WikiStory
    attr_accessor :name, :labels, :story_type, :id, :current_state, :estimate

    def initialize(*args)
      story_line = args[0].split("\n|")
      story_line.shift
      @name = story_line[0].strip
      @labels = story_line[1].strip
      @story_type = story_line[2].strip
      @id = story_line[3].gsub(/\{|\}|Pivotal|\||\W/, '')
      @current_state = story_line[4].gsub(/align="right"|\W/, '')
      @estimate = story_line[5].gsub(/align="right"|'|\||\W/, '')
    end

    def to_s
      out = <<-EOL 
      *****************************************
          name: "#{@name}"
          labels: "#{@labels}"
          story_type: "#{@story_type}"
          id: #{@id}
          current_state: "#{@current_state}"
          estimate: #{@estimate}
          EOL

    end
  end

  def to_wiki_summary
    "#{summary_wiki_header}#{summary_wiki_body}#{summary_wiki_footer}"
  end


  private 

  def section_title(title)
    "\n==#{title}==\n#{TITLE_MAP[title]}\n"
  end

  def summary_wiki_header
    section_title("Sprint Overview") +
    <<-EOF
{| border="1"
|+ Sprint Overview
!
! Points Committed to in Planning
! Sprint Additions
! Sprint Removals
! Total Points for the Sprint
! Total Points Delivered
! Overall % Completed
! Committed to Completed Ratio
    EOF
  end

  def summary_wiki_body
    ret = ""
    [{section: 'Feature Points:', totals: @feature_summary}, {section: 'Bug Points:', 
      totals: @bug_summary}, {section: 'Chore Points:', totals: @chore_summary},
      {section: 'Total Points:', totals: @total_summary}].each do |row|
      ret+="|-\n"
      ret+="| '''#{row[:section]}'''\n"
      row[:totals].each {|number| ret+="| #{number}\n"}
    end
    ret+="|}\n"
  end

  def summary_wiki_footer
    "Sprint Velocity = #{@velocity} (Based of off the last four sprints)\n"
  end

end
