require 'yaml'
require './converter'
require 'pivotal-tracker-api'

class Array
  def -(other_array)
    ret = []

    other_array_ids, self_ids = [other_array, self].map {|a| a.inject({}) { |m,v| m[v.id] = v; m }}

    other_array_ids_keys = other_array_ids.keys.map(&:to_i)

    self_ids.each do |k,v|
      ret << v unless other_array_ids_keys.member?(k.to_i)
    end 
  
    ret.compact
  end
end

class Sprint

  include StoryConverter

  def initialize(args=nil)
    if args[0] and File.directory?(args[0])
      @log_location = args[9]
    else
      $stderr.print "No valid log directory was given, do you want to use /tmp? [Y/n] "
      if gets.chomp == 'n'
        enter_text = "Enter log location [/tmp]: "
        $stderr.print enter_text
        while @log_location == '' or !File.directory?((@log_location = gets.chomp))
          (@log_location = '/tmp'; break) if @log_location == ''
          $stderr.print "#{@log_location} is not a valid directory."
          $stderr.print enter_text
        end
      else
        @log_location = '/tmp'
      end
    end
    PivotalService.set_token(YAML::load_file("./pivotal.yml")['token'])
  end  

  def past_sprint_stories(offset=1)
    @stories ||= get_iteration('done', {limit: 1, offset: (offset.to_i*-1)}) 
  end

  def current_sprint_stories
    @stories ||= get_iteration('current') 
  end

  def stories_committed_to(wiki="#{@log_location}/log.txt")
    @stories_committed ||= to_pivotal_stories(wiki)
  end

  def point_totals(section, remove_state=false)
    case section
    when 'backlog'
      @b_total, @b_features, @b_chores, @b_bugs = 0, 0, 0, 0
      ret = [(remove_state ? @stories : accepted(@stories)), @b_features, @b_bugs, @b_chores, @b_total]      
    when 'committed'
      @c_total, @c_features, @c_chores, @c_bugs = 0, 0, 0, 0
      ret = [@stories_committed, @c_features, @c_bugs, @c_chores, @c_total]
    when 'removals'
      @r_total, @r_features, @r_chores, @r_bugs = 0, 0, 0, 0
      ret = [@removal_stories, @r_features, @r_bugs, @r_chores, @r_total]
    when 'additions'
      @a_total, @a_features, @a_chores, @a_bugs = 0, 0, 0, 0
      ret = [@addition_stories, @a_features, @a_bugs, @a_chores, @a_total]
    end
    ret.first.each do |s|
      ret[4]+=s.estimate.to_i
      case s.story_type
      when 'feature'
        ret[1]+=s.estimate.to_i
      when 'bug'
        ret[2]+=s.estimate.to_i
      when 'chore'
        ret[3]+=s.estimate.to_i
      end 
    end
    ret
  end

  def removals
    @removal_stories = @stories_committed - accepted(@stories)
  end

  def additions
    @addition_stories = accepted(@stories) - @stories_committed
  end

  def summary_totals(parts)
    p = parts.map {|s| s.shift; s}
    t_f,t_b,t_c,t_t=total_points(p)
    d_f,d_b,d_c,d_t=total_points(p)
    op_f,op_b,op_c,op_t=percents(t_f,t_b,t_c,t_t,d_f,d_b,d_c,d_t)
    cc_f,cc_b,cc_c,cc_t=percents(p[0][0],p[0][1],p[0][2],p[0][3],d_f,d_b,d_c,d_t)
    @feature_summary, @bug_summary, @chore_summary, @total_summary = [], [], [], []
    @feature_summary = [p[0][0],p[2][0],p[1][0],t_f,d_f,op_f,cc_f]
    @bug_summary = [p[0][1],p[2][1],p[1][1],t_b,d_b,op_b,cc_b]
    @chore_summary = [p[0][2],p[2][2],p[1][2],t_c,d_c,op_c,cc_c]
    @total_summary = [p[0][3],p[2][3],p[1][3],t_t,d_t,op_t,cc_t]
    @velocity = parts[0][3]
  end

  def total_points(p)
    #[c_f, c_b, c_c, c_t], [r_f, r_b r_c, r_t], [a_f, a_b, a_c, a_t], [b_f, b_b, b_c, b_t]]
    [
      p[0][0] - p[1][0] + p[2][0],
      p[0][1] - p[1][1] + p[2][1],
      p[0][2] - p[1][2] + p[2][2],
      p[0][3] - p[1][3] + p[2][3]
    ]
  end

  def percents(*args)
    [
      div(args[4], args[0]),
      div(args[5], args[1]),
      div(args[6], args[2]),
      div(args[7], args[3])  
    ]
  end

  def div(a,b)
    return "0.0%" if a.to_i == 0
    b.to_i == 0 ? "infinity" : "#{'%.1f' % ((a.to_f / b.to_f)*100.0).to_s}%"
  end

  def accepted(stories)
    stories.reject {|s| s.current_state != 'accepted'}
  end

  def apply_end_of_sprint_status
    end_of_sprint = @stories.inject({}) {|m,v| m[v.id]=v; m}
    @stories_committed.each do |s|
      r = end_of_sprint[s.id.to_i]
      s.current_state = r ? r.current_state : "removed"
    end
  end

  def header
    <<-EOF
[[IDG/Sprint_Logs/Mobile]]
=Sprint 0XXX=
    EOF
  end

  def get_iteration(iter, options=nil)
    limit = options[:limit] if options
    offset = options[:offset] if options
    projects = YAML::load_file('./pivotal.yml')['project']
    stories = projects.map do |project_id|
      project = PivotalService.one_project(project_id, Scorer::Project.fields)
      iteration = (not limit or not offset) ? 
      PivotalService.iterations(project_id, iter) : 
      PivotalService.iterations(project_id, iter, [], limit, offset) 
      iteration.stories
    end
    filter(stories.flatten)
  end

  def filter(stories)
    return unless stories
    stories.reject {|s| s.estimate.to_i < 0 }
  end

  def goals(goals="")
    <<-EOF
=Sprint Improvement Goals=
At the end of each Sprint, the team identifies areas to incrementally improve.  Below are the things identified in the previous Sprint:
#{goals}
=Sprint Retrospective Notes=
Each Sprint ends with a Sprint Retrospective, where the team inspects how the Sprint went, and identifies areas to adapt in order to improve the process on the next pass.  These are summary notes from that meeting.
==What's Working==

==Not Working or Need to Tweak==


==Things to Try Next Sprint==

==Estimations of Story Point==
This section is to discuss stories that need point adjustments.
{| border="1"
|+ Updated Point Estimations
! User Story
! Product
! Story Type
! Pivotal #
! Original Estimations
! Final Estimations
|-
|}
    EOF
  end

  def write_log(out)
    log_file = "#{@log_location}/log%s.txt"
    file = sprintf(log_file, '')
    time_str = "-#{Time.now.to_i}"
    if File.exists?(file)
      system "mv #{file} #{sprintf(log_file, time_str)}"
    end
    f = open(file, 'w')
    f.write(out)
    f.close
  end
end

