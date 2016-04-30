def init
  super
  sections.place(:settings).after_any(:alpha)
end

def settings
  @tasks = Registry.all(:rake_task)
  return if @tasks.empty?
  @tasks = @tasks.sort_by {|t| t.full_path == 'default' ? '_' : t.full_path }
  erb(:rake_tasks)
end