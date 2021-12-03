#/usr/bin/env perl
###############################################################################
#
# @file Request.pm
#
# @brief Eulerian Request module used to send HTTP request to remote Peer.
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
package Eulerian::Request;
#
# Enforce compilor rules
#
use strict; use warnings;
#
# Import HTTP::Headers
#
use HTTP::Headers;
#
# Import HTTP::Request
#
use HTTP::Request;
#
# Import LWP::UserAgent
#
use LWP::UserAgent;
#
# Import IO::Socket::SSL
#
use IO::Socket::SSL;
#
# Import HTTP::Status
#
use HTTP::Status qw( :constants :is status_message );
#
# Import JSON
#
use JSON;
#
# Import Encode
#
use Encode;
#
# @brief Create new HTTP Headers.
#
# @param $class - Eulerian::HTTP class.
#
# @return HTTP Headers.
#
sub headers
{
  return HTTP::Headers->new();
}
#
# @brief Test if the content type of given HTTP response is a
#        JSON format.
#
# @param $class - Eulerian::Request Class.
# @param $response - HTTP response.
#
# @return 1 - Content type is JSON.
# @return 0 - Content type isnt JSON.
#
sub is_json
{
  my ( $class, $response ) = @_;
  my $type;

  # Get content type value from HTTP response
  $type = $response->header( 'content-type' );
  if( defined( $type ) ) {
    # Split content type into an array.
    my @subtypes = split( '; ', $type );
    # Iterate on subtypes entries
    foreach my $subtype ( @subtypes ) {
      # Test if subtype is JSON format
      if( $subtype eq 'application/json' ) {
        return 1;
      }
    }
  }

  return 0;
}
#
# @brief Get JSON object from HTTP response.
#
# @param $class - Eulerian::Request class.
# @param $response - HTTP response.
#
# @return JSON object.
#
sub json
{
  my ( $class, $response ) = @_;
  my $data = undef;

  if( $class->is_json( $response ) ) {
    $data = $response->decoded_content;
    if( defined( $data ) ) {
      chomp( $data );
      $data = encode( 'utf-8', $data );
      $data = decode_json( $data );
    }
  }

  return $data;
}
#
# @brief Send HTTP request on given url.
#
# @param $class - Eulerian Request class.
# @param $method - HTTP method.
# @param $url - Remote URL.
# @param $headers - HTTP headers.
# @param $what - Data of POST request.
# @param $type - Data type of POST request
# @param $file - Local file path used to store HTTP reply.
#
sub request
{
  my ( $class, $method, $url, $headers, $what, $type, $file ) = @_;
  my $endpoint;
  my $request;

  # Ensure default type
  $type = $type || 'application/json';

  # Sanity check POST arguments
  if( $method eq 'POST' ) {
    if( ! ( defined( $what ) && defined( $type ) ) ) {
      return undef;
    } else {
      # Setup Content_Length and Content_Type
      $headers->push_header( Content_Length => length( $what ) );
      $headers->push_header( Content_Type => $type );
    }
  }

  # Create HTTP Request
  $request = HTTP::Request->new( $method, $url, $headers, $what );

  # Create End Point used to communicate with remote server
  $endpoint = LWP::UserAgent->new(
    keep_alive => 0,
    cookie_jar => {},
    ssl_opts   => {
      SSL_verifycn_publicsuffix => '',
      SSL_verify_mode           => IO::Socket::SSL::SSL_VERIFY_NONE,
      verify_hostname           => 0,
      SSL_hostname              => '',
    },
  );

  # Send Request, wait response if file is defined reply content is
  # writen into local file.
  return $endpoint->request( $request, $file );
}
#
# @brief Do HTTP Get on given URL.
#
# @param $class - Eulerian::HTTP class.
# @param $url - Remote URL.
# @param $headers - HTTP::Headers.
# @param $file - Local file path.
#
# @return Array( HTTP::Status, Response data )
#
sub get
{
  my ( $class, $url, $headers, $file ) = @_;
  return request( $class, 'GET', $url, $headers, undef, undef, $file );
}
#
# @brief Do HTTP Post on given URL.
#
# @param $class - Eulerian::HTTP class.
# @param $url - Remote URL.
# @param $headers - HTTP::Headers.
# @param $what - Request Data.
# @param $type - Request Data Type.
#
# @return Array( HTTP::Status, Response data )
#
sub post
{
  my ( $class, $url, $headers, $what, $type ) = @_;
  return request( $class, 'POST', $url, $headers, $what, $type );
}
#
# @brief Decode HTTP response, create Reply context.
#
# @param $class - Eulerian Request class.
# @param $response - HTTP response.
#
# @return Reply context.
#
#use Data::Dumper;
sub reply
{
  my ( $class, $response ) = @_;
  my $code = $response->code;
  my $json;
  my %rc;

  #print Dumper( $response );

  if( $code != HTTP_OK ) {
    $rc{ error } = 1;
    $rc{ error_code } = $code;
    $json = $class->json( $response );
    $rc{ error_msg } = defined( $json ) ?
      encode_json( $json ) :
      $response->status_line;
  } else {
    $rc{ error } = 0;
    $rc{ response } = $response;
  }

  return \%rc;
}
#
# End up module properly
#
1;
