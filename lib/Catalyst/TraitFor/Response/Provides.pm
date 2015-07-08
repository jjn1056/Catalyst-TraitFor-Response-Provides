package Catalyst::TraitFor::Response::Provides;

use Moose::Role;
use HTTP::Headers::ActionPack;
use Plack::MIME;
use Scalar::Util;
use Catalyst::Utils;

my $cn = HTTP::Headers::ActionPack->new
  ->get_content_negotiator;

my $method_not_acceptable = sub {
  $_[0]->status(406);
  $_[0]->body("Method Not Acceptable");   
};

my $normalize_mime = sub {
  my ($res, %provides) = @_;
  return %provides = map {
    my $value = $provides{$_};
    $_ =~m[/] ? ( $_ => $value : Plack::MIME->mime_type(".$_") => $value);
  } keys(%provides);
};

sub provides {
  my $self = shift;

  die "You cannot provide a response if you've already set one..."
    if($self->has_body || $self->has_write_fh);

  my %provides = $self->$normalize_mime(@_);
  my @provides = keys %provides;
  my $accept = $self->_context->req->header('Accept') ||
    $provides{default} ||
     $_[0];

  my $not_acceptable_cb = exists($provides{not_acceptable_cb}) ?
    delete $provides{not_acceptable_cb} : $method_not_acceptable;

  $self->headers->header('Vary' => 'Accept');
  $self->headers->header('Accepts' => (join ',', @provides));

 if(my $which = $cn->choose_media_type(\@formats, $accept)) {
    if(my $response_proto = $formats{$which}) {
      $self->content_type($which);
      if(Scalar::Util::blessed $response_proto) {
        if($response_proto->can('as_psgi')) {
          $self->from_psgi_response($response_proto);
        } elsif($response_proto->can('getline')) {
          $self->body($response_proto);
        } elsif($response_proto->can('to_app')) {
          my $env = $self->_context->Catalyst::Utils::env_at_action;
          $self->from_psgi_response( $response_proto->to_app->($env));
        } elsif($response_proto->can('process')) {
          $self->_context->forward($response_proto);
        } else {
          die "Don't know what to do with object $response_proto";
        }
      } elsif( ref \$response_proto eq 'SCALAR') {
        $self->body($response_proto);
      } elsif(ref $response_proto eq 'GLOB' ) {
        $self->body($response_proto);
      } elsif( ref $response_proto eq 'ARRAY') {
        $self->from_psgi_response($response_proto);
      } elsif( ref $response_proto eq 'CODE') {
        $self->from_psgi_response($response_proto);
      } else {
        die "Don't know how to provide a response from $response_proto";
      }
    } else {
      $self->$not_acceptable_cb;      
    }
  }
}

1;

=head1 NAME

Catalyst::TraitFor::Response::Provides - Negotiate a response

=head1 SYNOPSIS

For L<Catalyst> v5.90090+

    package MyApp;

    use Catalyst;

    MyApp->request_class_traits(['Catalyst::TraitFor::Response::Provides']);
    MyApp->setup;

For L<Catalyst> older than v5.90090

    package MyApp;

    use Catalyst;
    use CatalystX::RoleApplicator;

    MyApp->apply_request_class_roles('Catalyst::TraitFor::Response::Provides');
    MyApp->setup;

In a controller:

    package MyApp::Controller::Example;

    use Moose;
    use MooseX::MethodAttributes;

    sub myaction :Local {
      my ($self, $c) = @_;
      $c->res->provides(
        'html' => $c->view('HTML'),
        'application/json' => $c->view('JSON'),
        'text/plain' => 'A plain text response',
      );
    }

=head1 DESCRIPTION

  TBD

=head1 METHODS

This role defines the following methods:

=head2 provides (%map)

  TBD

=head1 AUTHOR
 
John Napiorkowski L<email:jjnapiork@cpan.org>
  
=head1 SEE ALSO
 
L<Catalyst>, L<Catalyst::Model>, L<HTML::Formhandler>, L<Module::Pluggable>

=head1 COPYRIGHT & LICENSE
 
Copyright 2015, John Napiorkowski L<email:jjnapiork@cpan.org>
 
This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

__END__

If the value is a string, that's the body
If the value is an object and ->can('as_psgi') use ->from_psgi_response
If the values is an arrayref and looks lilke a PSGI tuple, use ->from_psgi_response
If the value looks like a filehandle, thats the body (->can('getline') or is glob)
If the value is a coderef, this is a streaming psgi response, send it to ->from_psgi_response

If the value is an object and ->can('to_app') call to_app($nev) and use ->from_psgi_response
If the value is an object and looks like a View, forward to it.(or make default...) ???

