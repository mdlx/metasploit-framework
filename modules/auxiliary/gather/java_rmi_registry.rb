##
# This module requires Metasploit: http://metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##

require 'msf/core'
require 'rex/java/serialization'

class Metasploit3 < Msf::Auxiliary

  include Msf::Auxiliary::Report
  include Msf::Java::Rmi::Client

  def initialize
    super(
      'Name'        => 'Java RMI Registry Interfaces Enumeration',
      'Description'    => %q{
        This module gathers information from an RMI endpoint running an RMI registry
        interface. It enumerates the names bound in a registry and looks up each
        remote reference.
      },
      'Author'      => ['juan vazquez'],
      'License'     => MSF_LICENSE,
      'References'  =>
        [
          ['URL', 'http://docs.oracle.com/javase/8/docs/platform/rmi/spec/rmiTOC.html']
        ]
    )

    register_options(
      [
        Opt::RPORT(1099)
      ], self.class)
  end

  def run
    print_status("#{peer} - Sending RMI Header...")
    connect

    send_header
    ack = recv_protocol_ack
    if ack.nil?
      print_error("#{peer} - Filed to negotiate RMI protocol")
      disconnect
      return
    end

    print_status("#{peer} - Listing names in the Registry...")

    begin
      names = send_registry_list
    rescue ::Rex::Proto::Rmi::Exception => e
      print_error("#{peer} - List raised exception #{e.message}")
      return
    end

    if names.nil?
      print_error("#{peer} - Failed to list names")
      return
    end

    if names.empty?
      print_error("#{peer} - Names not found in the Registry")
      return
    end

    print_good("#{peer} - #{names.length} names found in the Registry")

    names.each do |name|

      begin
        remote_reference = send_registry_lookup(name: name)
      rescue ::Rex::Proto::Rmi::Exception => e
        print_error("#{peer} - Lookup of #{name} raised exception #{e.message}")
        next
      end

      if remote_reference.nil?
        print_error("#{peer} - Failed to lookup #{name}")
        next
      end

      print_good("#{peer} - Name #{name} (#{remote_reference[:object]}) found on #{remote_reference[:address]}:#{remote_reference[:port]}")
      report_service(
        :host => remote_reference[:address],
        :port => remote_reference[:port],
        :name => 'java-rmi',
        :info => "Name: #{name}, Stub: #{remote_reference[:object]}"
      )
    end
  end
end
