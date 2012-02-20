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
    settings = YAML.load(IO.read(File.join(File.dirname(__FILE__), "config.yaml")))
    if settings
      $server_uri = settings['server_uri']
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
  "Small area estimation for disabilities in the UK. Send a GET request to url /{area}/{disability}{year}."
end

#fetch the estimation results for the area, disability type and year
#or use taverna to create the results 
get '/:area/:disability/:year' do
check_server
respond_to do |wants|
         wants.xml   {
            content_type "application/xml"
            builder :estimate, :locals => {:area => params[:area], :disability => params[:disability], :year => params[:year]}
         }
         wants.html {
            content_type 'text/html'
            haml :estimate, :locals => {:area => params[:area], :disability => params[:disability], :year => params[:year]}
         }
         wants.other { 
           content_type 'text/plain'
           error 406, "Not Acceptable" 
         }
      end
end