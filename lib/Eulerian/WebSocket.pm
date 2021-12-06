#/usr/bin/env perl
###############################################################################
#
# @file WebSocket.pm
#
# @brief Eulerian Request module used to
#
# @author Thorillon Xavier:x.thorillon@eulerian.com
#
# @date 26/11/2021
#
# @version 1.0
#
###############################################################################
#
# Setup module name.
#
package Eulerian::WebSocket;
#
# Enforce compilor rules
#
use strict; use warnings;
#
# Import IO::Socket::INET
#
use IO::Socket::INET();
#
# Import Protocol::WebSocket::Client
#
use Protocol::WebSocket::Client;
#
# Import IO::Select
#
use IO::Select;
#
# @brief Allocate and initialize a new Eulerian Websocket.
#
# @param $class - Eulerian::WebSocket class.
# @param $host - Remote host.
# @param $port - Remote port.
#
# @return Eulerian WebSocket instance.
#
sub new
{
  my ( $class, $host, $port ) = @_;
  return bless( {
    _HOOK => undef,
    _SELECT => undef,
    _RFDS => undef,
    _SOCKET => IO::Socket::INET->new(
      PeerAddr => $host, PeerPort => $port,
      Blocking => 1, Proto => 'tcp'
      ),
    }, $class
  );
}
#
# @brief Get Socket.
#
# @param $self - Eulerian::WebSocket instance.
#
# @return Socket.
#
sub socket
{
  return shift->{ _SOCKET };
}
#
# @brief Get Eulerian Websocket Remote Host.
#
# @param $self - Eulerian::WebSocket instance.
#
# @return Remote Host.
#
sub host
{
  return shift->socket()->peerhost();
}
#
# @brief Get Eulerian Websocket Remote Port.
#
# @param $self - Eulerian::WebSocket instance.
#
# @return Remote Port.
#
sub port
{
  return shift->socket()->peerport();
}
#
# @brief On write Websocket handler.
#
# @param $self - WebSocket.
# @param $data - Data to be writen
#
# @return Writen Size.
#
sub on_write
{
  my ( $peer, $buf ) = @_;
  $peer->{ _WS }->{ _SOCKET }->syswrite( $buf );
}
#
# @brief On read Websocket handler.
#
# @param $self - Websocket.
#
# @return
#
sub on_read
{
  my ( $peer, $buf ) = @_;
  my $ws = $peer->{ _WS };
  $ws->{ _HOOK }( $ws, $buf );
}
#
# @brief On error Websocket handler.
#
# @param $self - Websocket.
#
# @return
#
sub on_error
{
  my ( $self, $error ) = @_;
  print STDERR "Websocket error : $error\n";
}
#
# @brief On connect Websocket handler.
#
# @param $self - Websocket.
#
# @return
#
sub on_connect
{
}
#
# @brief Get Count of Pending events
#
# @param $socket - Socket.
# @param $rfds - Read Fds set.
#
# @return Pending events count.
#
sub pendings
{
  my ( $socket, $rfds ) = @_;
  my @pendings;

  # Create Multiplexer on demand
  $$rfds ||= new IO::Select();

  # Monitor socket for IO events
  $$rfds->add( $socket );

  # Get pendings events
  @pendings = $$rfds->can_read();

  # Unmonitor socket for IO events
  $$rfds->remove( $socket );

  return scalar( @pendings );
}
#
# @brief
#
# @param $self
# @param $url
# @param $hooks
#
sub join
{
  my ( $self, $url, $hook ) = @_;
  my $socket = $self->socket();
  my $bufsize = 252000;
  #my $bufsize = 65535 * 4;
  my $offset = 0;
  my $buf = '';
  my $read;
  my $rfds;
  my $peer;
  #my %params = (
  #  max_payload_size => $bufsize
  #);

  # Create a Websocket
  #$peer = Protocol::WebSocket::Client->new( url => $url, %params );
  $peer = Protocol::WebSocket::Client->new( url => $url );

  # Setup Websocket hooks
  $peer->on( write   => \&Eulerian::WebSocket::on_write );
  $peer->on( read    => \&Eulerian::WebSocket::on_read );
  $peer->on( error   => \&Eulerian::WebSocket::on_error );
  $peer->on( connect => \&Eulerian::WebSocket::on_connect );

  # Save back refs
  $self->{ _HOOK } = $hook;
  $peer->{ _WS } = $self;

  # Connect on remote host
  $peer->connect;

  # If connected
  if( defined( $socket->connected ) ) {
    for(; defined( $socket ); ) {
      $read = $socket->sysread( $buf, $bufsize, $offset );
      if( $read > 0 ) {
        $peer->read( $buf );
        undef $buf;
      } else {
        close( $socket );
        undef( $socket );
        last;
      }
    }
  }

  # Disconnect from remote host
  $peer->disconnect;

}
#
# End up module properly
#
1;
