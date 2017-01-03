defmodule HelloNetwork do

  require Logger

  alias Nerves.Networking
  alias Nerves.SSDPServer
  alias Nerves.Lib.UUID

  @interface :eth0

  def start(_type, _args) do
    unless :os.type == {:unix, :darwin} do     # don't start networking unless we're on nerves
      {:ok, _} = Networking.setup @interface
    end
    #publish_node_via_ssdp(@interface)
    #publish_node_via_mdns(@interface)
    {:ok, self}
  end

  # define SSDP service type that allows discovery from the cell tool,
  # so a node running this example can be found with `cell list`
  defp publish_node_via_ssdp(_iface) do
    usn = "uuid:" <> UUID.generate
    st = "urn:nerves-project-org:service:cell:1"
    #fields = ["x-node": (node |> to_string) ]
    {:ok, _} = SSDPServer.publish usn, st
  end

  def publish_node_via_mdns(iface) do
    Logger.debug "[1] iface: #{IO.inspect iface}"
    {:ok, ifaces} = :inet.getifaddrs
    {'eth0', eth0} = List.keyfind(ifaces, 'eth0', 0)
    Logger.debug "[2] eth0"
    eth0ip4 = eth0[:addr]
    Logger.debug "[3] eth0 ip4"
    Mdns.Server.start

    # Make `ping rpi.local` from a laptop work.
    Mdns.Server.set_ip(eth0ip4)
    Mdns.Server.add_service(%Mdns.Server.Service{
      domain: "rpi.local",
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
      data: "rpi._http._tcp.local",
      ttl: 10,
      type: :ptr
    })
    Mdns.Server.add_service(%Mdns.Server.Service{
      domain: "rpi._http._tcp.local",
      data: "1 1 4000 rpi.local",
      ttl: 10,
      type: :srv
    })
    #Mdns.Server.add_service(%Mdns.Server.Service{
    #  domain: "rpi._http._tcp.local",
    #  data: ["txtvers=1"],
    #  ttl: 10,
    #  type: :txt
    #})

    Logger.debug "[4] done"
    :ok
  end

  @doc "Attempts to perform a DNS lookup to test connectivity."
  def test_dns(hostname \\ 'nerves-project.org') do
    :inet_res.gethostbyname(hostname)
  end
end
