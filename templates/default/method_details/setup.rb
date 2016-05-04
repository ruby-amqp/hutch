def init
  super
  sections.last.place(:settings).after(:source)
end
