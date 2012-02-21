builder do |xml|
  xml.instruct! :xml, :version => '1.0'
  xml.request do
    xml.area area
    xml.disability disability
    xml.year year
  end
  xml.results do
    xml.disability_total disab_total
    xml.population_total pop_total
    xml.percentage percentage
  end
end
