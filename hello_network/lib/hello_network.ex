defmodule HelloNetwork do

  require Logger

  alias Nerves.Networking

  def start(_type, _args) do
    unless :os.type == {:unix, :darwin} do     # don't start networking unless we're on nerves
      hostname = who_am_i?()
      :net_kernel.stop
      :net_kernel.start([:erlang.binary_to_atom(hostname, :utf8)])
      {:ok, _} = Networking.setup @interface
      publish_node_via_mdns(hostname)
    end
    {:ok, self}
  end

  def who_am_i?() do
    {:ok, hostname} = :inet.gethostname()
    List.to_string hostname
  end

  def publish_node_via_mdns(hostname) do
    Logger.debug "[1] hostname: #{hostname}"
    {:ok, ifaces} = :inet.getifaddrs
    {'eth0', eth0} = List.keyfind(ifaces, 'eth0', 0)
    Logger.debug "[2] eth0"
    eth0ip4 = eth0[:addr]
    Logger.debug "[3] eth0 ip4"
    Mdns.Server.start

    # Make `ping rpi1.local` from a laptop work.
    Mdns.Server.set_ip(eth0ip4)
    Mdns.Server.add_service(%Mdns.Server.Service{
      domain: "#{hostname}.local",
      data: :ip,
      ttl: 10,
      type: :a
    })

    # Make `dns-sd -B _services._dns-sd._udp` show
    # an HTTP service.
    Mdns.Server.add_service(%Mdns.Server.Service{
      domain: "_services._dns-sd._udp.local",
      data: "_http._tcp.local",
      ttl: 10,
      type: :ptr
    })

    Mdns.Server.add_service(%Mdns.Server.Service{
      domain: "_http._tcp.local",
      data: "#{hostname}._http._tcp.local",
      ttl: 10,
      type: :ptr
    })

    # This should be the DNS-SD way of defining a service instance:
    # its priority, weight and host.
    # It doesn't work.
    # The packet sent by Mdns is corrupt as seen by Wireshark
    # and undecodable by Erlang :inet_dns.decode/1.
    #Mdns.Server.add_service(%Mdns.Server.Service{
    #  domain: "#{hostname}._http._tcp.local",
    #  data: "0 0 4000 #{hostname}.local",
    #  ttl: 10,
    #  type: :srv
    #})

    Mdns.Server.add_service(%Mdns.Server.Service{
      domain: "#{hostname}._http._tcp.local",
      data: ["txtvers=1", "port=4000"],
      ttl: 10,
      type: :txt
    })

    Logger.debug "[4] done"
    :ok
  end

  @doc "Attempts to perform a DNS lookup to test connectivity."
  def test_dns(hostname \\ 'nerves-project.org') do
    :inet_res.gethostbyname(hostname)
  end
end
