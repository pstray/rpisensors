#!/usr/bin/env perl
use Mojolicious::Lite;

my $id = 0;

get '/' => sub {
  my $c = shift;
  $c->render();
} => 'index';

get '/events' => sub {
    my $c = shift;

    # last id known to client
    my $last_id = $c->req->headers->header('Last-Event-ID') || 0;
    
    # Increase the timeout, this is a long-"poll" after all...
    $c->inactivity_timeout(300);

    
    $c->res->headers->content_type("text/event-stream");
    $c->res->headers->cache_control("no-cache");
    $c->write();

    my $cb = $c->app->log->on(message => sub {
				  my($log, $level, @lines) = @_;
				  my $data = "[$level] @lines";
				  $data =~ s/^/data: /mg;
				  $c->write("id: $id\nevent: log\n$data\n\n");
				  $id++;
			      });
    $c->on(finish => sub {
	       $c->app->log->unsubscribe(message => $cb);
	   });

    while ($id < $last_id) {
	# fast forward to!
	$id++;
    }
    
} => 'events';

app->secrets(['Some random secret string that nobody would guess']);
app->start;
__DATA__
@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head>
    <title><%= title %></title>
    <%= content_for 'header' %>
  </head>
  <body><%= content %></body>
</html>

@@ index.html.ep
% layout 'default';
% title 'Welcome';
% content_for 'header' => begin
  <script src="//code.jquery.com/jquery-1.11.3.min.js"></script>
  <script>
  if (!!window.EventSource) {
      var source = new EventSource('<%= url_for 'events' %>');
      source.addEventListener('log', function (event) {
	  $('#log').append(event.data+"\n");
			  }, false);
  }
  </script>
% end
<h1>Welcome to the Event-server!</h1>
<pre id="log"></pre>
  
  
