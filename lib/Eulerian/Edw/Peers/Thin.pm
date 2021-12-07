#/usr/bin/env perl
###############################################################################
#
# @file Thin.pm
#
# @brief Eulerian Data Warehouse Thin Peer Module definition.
#
#   This module is aimed to provide access to Eulerian Data Warehouse
#   Analytics Analysis Through Websocket Protocol.
#
# @author Thorillon Xavier:x.thorillon@eulerian.com
#
# @date 26/11/2021
#
# @version 1.0
#
###############################################################################
#
# Setup module name
#
package Eulerian::Edw::Peers::Thin;
#
# Enforce compilor rules
#
use strict; use warnings;
#
# Inherited interface from Eulerian::Edw::Peer
#
use parent 'Eulerian::Edw::Peer';
#
# Import Eulerian::WebSocket
#
use Eulerian::WebSocket;
#
# Import Switch
#
use Switch;
#
# Import JSON
#
use JSON;
#
# @brief Allocate and initialize a new Eulerian Data Warehouse Thin Peer.
#
# @param $class - Eulerian Data Warehouse Thin Peer class.
# @param $setup - Setup attributes.
#
# @return Eulerian Data Warehouse Peer.
#
sub new
{
  my ( $class, $setup ) = @_;
  my $self;

  # Call base instance constructor
  $self = $class->SUPER::create( 'Eulerian::Edw::Peers::Thin' );

  # Setup Default host value
  $self->host( 'edwaro' );

  # Setup Default ports value
  $self->ports( [ 8080, 8080 ] );

  # Setup Rest Peer Attributes
  $self->setup( $setup );

  return $self;
}
#
# @brief Setup Eulerian Data Warehouse Peer.
#
# @param $self - Eulerian Data Warehouse Peer.
# @param $setup - Setup entries.
#
sub setup
{
  my ( $self, $setup ) = @_;

  # Setup base interface values
  $self->SUPER::setup( $setup );

  # Setup Thin Peer specifics options

}
#
# @brief Dump Eulerian Data Warehouse Peer setup.
#
# @param $self - Eulerian Data Warehouse Peer.
#
sub dump
{
  my $self = shift;
  my $dump = "\n";
  $self->SUPER::dump();
  print( $dump );
}
#
# @brief Get remote URL to Eulerian Data Warehouse Platform.
#
# @param $self - Eulerian Data Warehouse Peer.
#
# @return Remote URL to Eulerian Data Warehouse Platform.
#
sub url
{
  my $self = shift;
  my $aes = shift;
  my $secure = $self->secure();
  my $ports = $self->ports();
  my $url;

  $url = defined( $aes ) ?
    $secure ? 'wss://' : 'ws://' :
    $secure ? 'https://' : 'http://';
  $url .= $self->host() . ':';
  $url .= $ports->[ $secure ] . '/edwreader/';
  $url .= $aes if( defined( $aes ) );

  return $url;
}
#
# @brief Create a new JOB on Eulerian Data Warehouse Rest Platform.
#
# @param $self - Eulerian Data Warehouse Peer.
# @param $command - Eulerian Data Warehouse Command.
#
# @return Reply context.
#
use Data::Dumper;
sub create
{
  my ( $self, $command ) = @_;
  my $response;
  my $status;

  # Get Valid Headers
  $status = $self->headers();
  if( ! $status->error() ) {
    # Post new JOB to Eulerian Data Warehouse Platform
    $status = Eulerian::Request->post(
      $self->url(), $status->{ headers }, $command, 'text/plain'
      );
    if( ! $status->error() ) {
      my $json = Eulerian::Request->json( $status->{ response } );
      if( defined( $json ) && $json->{ status }->[ 1 ] != 0 ) {
        $status = Eulerian::Status->new();
        $status->error( 1 );
        $status->msg( $json->{ status }->[ 0 ] );
        $status->code( $json->{ status }->[ 1 ] );
      }
    }
  }

  return $status;
}
#
# @brief Dispatch Eulerian Data Warehouse Analytics Analysis result messages to
#        their matching callback hooks.
#
# @param $ws - Eulerian WebSocket.
# @param $buf - Received buffer.
#
use Data::Dumper;
sub dispatcher
{
  my ( $ws, $buf ) = @_;
  my $json = decode_json( $buf );
  my $type = $json->{ message };
  my $uuid = $json->{ uuid };
  my $self = $ws->{ _THIN };
  my $hooks = $self->hooks();
  my $rows = $json->{ rows };

  switch( $type ) {
    case 'add' {
      $hooks->on_add( $json->{ uuid }, $json->{ rows } );
    }
    case 'replace' {
      $hooks->on_replace( $json->{ uuid }, $json->{ rows } );
    }
    case 'headers' {
      #print Dumper( $json ) . "\n";
      $self->{ uuid } = $uuid;
      $hooks->on_headers(
        $json->{ uuid }, $json->{ timerange }->[ 0 ],
        $json->{ timerange }->[ 1 ], $json->{ columns }
      );
    }
    case 'progress' {
      $hooks->on_progress(
        $json->{ uuid }, $json->{ progress }
      );
    }
    case 'status' {
      $hooks->on_status(
        $json->{ uuid }, $json->{ aes }, $json->{ status }->[ 1 ],
        $json->{ status }->[ 0 ], $json->{ status }->[ 2 ]
      );
    }
    else {}
  }

}
#
# @brief Join Websocket stream, raise callback hooks accordingly to received
#        messages types.
#
# @param $self - Eulerian::Edw::Peers:Thin instance.
# @param $rc - Reply context of JOB creation.
#
# @return Reply context.
#
sub join
{
  my ( $self, $status ) = @_;
  my $json = Eulerian::Request->json( $status->{ response } );
  my $ws = Eulerian::WebSocket->new(
    $self->host(), $self->ports()->[ $self->secure() ]
    );
  my $url = $self->url( $json->{ aes } );
  $ws->{ _THIN } = $self;
  return $ws->join( $url, \&dispatcher );
}
#
# @brief Do Request on Eulerian Data Warehouse Platform.
#
# @param $self - Eulerian Data Warehouse Peer.
# @param $command - Eulerian Data Warehouse Command.
#
sub request
{
  my ( $self, $command ) = @_;
  my $response;
  my $status;
  my $json;

  # Create Job on Eulerian Data Warehouse Platform
  $status = $self->create( $command );

  if( ! $status->error() ) {
    # Join Websocket call user specific callback hooks
    $status = $self->join( $status );
  }

  return $status;
}
#
# @brief Cancel Job on Eulerian Data Warehouse Platform.
#
# @param $self - Eulerian::Edw::Peers::Rest instance.
# @param $rc - Reply context.
#
sub cancel
{
  my ( $self ) = @_;
  my $status;

  # Get Valid Headers
  $status = $self->headers();
  if( ! $status->error() && exists( $self->{ uuid } ) ) {
    my $uuid = $self->{ uuid };
    my $command = "KILL $uuid;";

    # Post new JOB to Eulerian Data Warehouse Platform
    $status = Eulerian::Request->post(
      $self->url(), $status->{ headers }, $command, 'text/plain'
      );

  }

  return $status;
}
#
# End Up module properly
#
1;
