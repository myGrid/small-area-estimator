# Copyright (c) 2012 The University of Manchester, UK.
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#  * Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
#
#  * Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
#  * Neither the names of The University of Manchester nor the names of its
#    contributors may be used to endorse or promote products derived from this
#    software without specific prior written permission. 
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
# Author: Ian Dunlop

require 'rubygems'
require 'bundler/setup'
require 'sinatra'
require 'haml'
require 'builder'
require 'rack/conneg'
require 't2server'

#a taverna server instance
$server = nil
#the location of the server
$server_uri = nil
#the workflow to run
$workflow = nil
#the data used by the workflow
$data = nil
#all the years that the data file covers
$years = nil
#all the districts/zones that the data file covers
$zones = nil
#all the disabilities
$disabilities = nil

# Initalise Conneg
use(Rack::Conneg) { |conneg|
  conneg.set :accept_all_extensions, false
  conneg.ignore('/stylesheets/')
  conneg.ignore_contents_of(File.join(File.dirname(__FILE__),'public'))
  conneg.provide([:html, :xml])
}

before do
  if negotiated?
    content_type negotiated_type
  end
end

def check_server()
  if (!defined?($server) || ($server == nil)) then
    settings = YAML.load_file(File.join(Dir.getwd(), "config.yaml"))
    $years = YAML.load_file(File.join(Dir.getwd(), "data", "years.yaml"))
    $zones = YAML.load_file(File.join(Dir.getwd(), "data", "zonenames.yaml"))
    $disabilities = YAML.load_file(File.join(Dir.getwd(), "data", "disabilities.yaml"))
    if settings
      $server_uri = settings['server_uri']
      file = File.open(File.join(Dir.getwd(), "workflow", settings['workflow']), 'r')
      $workflow = file.read
      $data = File.join(Dir.getwd(), "data", settings['data'])
      begin
       $server = T2Server::Server.connect($server_uri)
      rescue Exception => e  
        $server = nil
        redirect '/no_configuration'
      end
    else
      redirect '/no_configuration'
    end
  end
end

get '/' do
  check_server
  haml :index, :locals => {:zones => $zones, :years => $years, :disabilities => $disabilities}
end

#fetch the estimation results for the area, disability type and year
#or use taverna to create the results 
get '/:area/:disability/:year' do
check_server
run = T2Server::Run.create($server,$workflow)
run.set_input("disability", params[:disability])
run.set_input("district_in", params[:area])
run.set_input("year_in", params[:year])
run.upload_input_file("data", $data)
run.start
run.wait
#R/taverna returns results with leading/trailing [] so remove them
disability_total = run.get_output("disab_tot")[1..-1].chop
population_total = run.get_output("pop_tot")[1..-1].chop
percentage = run.get_output("pct")[1..-1].chop
respond_to do |wants|
         wants.xml   {
            content_type "application/xml"
            builder :estimate, :locals => {:area => params[:area], :disability => params[:disability], :year => params[:year], :disab_total => disability_total, :pop_total => population_total, :percentage => percentage}
         }
         wants.html {
            content_type 'text/html'
            haml :estimate, :locals => {:area => params[:area], :disability => params[:disability], :year => params[:year], :disab_total => disability_total, :pop_total => population_total, :percentage => percentage}
         }
         wants.other { 
           content_type 'text/plain'
           error 406, "Not Acceptable" 
         }
      end
  end
#fetch the estimation results for the area, disability type and year
#or use taverna to create the results 
post '/run' do
  check_server
  run = T2Server::Run.create($server,$workflow)
  run.set_input("disability", params[:disability])
  run.set_input("district_in", params[:zone])
  run.set_input("year_in", params[:year])
  run.upload_input_file("data", $data)
  run.start
  run.wait
  #R/taverna returns results with leading/trailing [] so remove them
  disability_total = run.get_output("disab_tot")[1..-1].chop
  population_total = run.get_output("pop_tot")[1..-1].chop
  percentage = run.get_output("pct")[1..-1].chop
  respond_to do |wants|
    wants.xml   {
    content_type "application/xml"
    builder :estimate, :locals => {:area => params[:zone], :disability => params[:disability], :year => params[:year], :disab_total => disability_total, :pop_total => population_total, :percentage => percentage}
    }
    wants.html {
    content_type 'text/html'
    haml :estimate, :locals => {:area => params[:zone], :disability => params[:disability], :year => params[:year], :disab_total => disability_total, :pop_total => population_total, :percentage => percentage}
    }
    wants.other { 
    content_type 'text/plain'
    error 406, "Not Acceptable" 
    }
  end
end
