class MenuHandler

  def initialize
    index, default = 0,"1"
    main_menu = {
    "run end of sprint for current sprint" => "current_sprint",
    "run end of sprint for previous sprint" => "past_sprint",
    "run beginning of sprint" => "beginning_of_sprint"
    }

    submenu = {2 => "\nWhich past sprint\n(e.g. last sprint = 1, next to last = 2): "}

    main_menu_keys = main_menu.keys

    $stderr.puts
    $stderr.puts
    36.times {$stderr.print "*"}
    $stderr.print " Menu "
    36.times {$stderr.print "*"}
    $stderr.puts
    $stderr.puts
    main_menu_keys.each do |c|
      $stderr.puts "#{index+=1}. #{c}"
    end

    $stderr.puts
    $stderr.print "[#{default}]: "
    choice = gets
    $stderr.puts

    choice = default if choice.chomp! == ""

    if submenu.keys.member? choice.to_i
      $stderr.print "#{submenu[choice.to_i]} "
      subchoice = gets
      subchoice.chomp!
    end

    if choice and choice =~ /\d+/  
      text = main_menu_keys[choice.to_i-1]
      if text
        method = main_menu[text]
        require './sprint'
        init
        if subchoice and subchoice =~ /\d+/
          send(method, subchoice)
        else
          send(method)
        end
      else
        error
      end
    else
      error
    end
  end

  def init
    @wiki = ""
    @sprint = Sprint.new(ARGV)
  end

  def current_sprint
    @sprint.stories_committed_to
    @sprint.current_sprint_stories
    output_wiki
  end

  def past_sprint(offset)
    @sprint.stories_committed_to
    @sprint.past_sprint_stories(offset)
    output_wiki
  end

  def beginning_of_sprint
    @sprint.current_sprint_stories
    b_totals = @sprint.point_totals('backlog', true)
    b_totals << 'remove_state'
    out = @sprint.to_wiki("Sprint Backlog", b_totals)
    puts out
    @sprint.write_log(out)
  end

  def output_wiki
    #backlog
    c_totals = @sprint.point_totals('committed')
    b_totals = @sprint.point_totals('backlog')
    @sprint.apply_end_of_sprint_status
    @wiki += @sprint.to_wiki("Sprint Backlog", c_totals)

    #removals
    @sprint.removals
    r_totals = @sprint.point_totals('removals')
    @wiki += @sprint.to_wiki("Sprint Removals", r_totals)

    #additions
    @sprint.additions
    a_totals = @sprint.point_totals('additions')
    @wiki += @sprint.to_wiki("Sprint Additions", a_totals)

    #goals and such
    @wiki += @sprint.goals

    #summary section
    @sprint.summary_totals([c_totals, r_totals, a_totals, b_totals])
    @wiki = "#{@sprint.to_wiki_summary}#{@wiki}"

    #header
    @wiki = "#{@sprint.header}#{@wiki}"

    puts @wiki
  end

  def error
    puts "invalid entry."
    exit
  end

end


MenuHandler.new

